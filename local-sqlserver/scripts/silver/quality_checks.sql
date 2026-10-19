:ON ERROR EXIT
SET NOCOUNT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 THROW 50700,'Expected local DataWarehouse.',1;
DECLARE @failures TABLE(check_name varchar(100), failures bigint);
INSERT @failures
SELECT 'customer null keys/dates',COUNT(*) FROM silver.crm_cust_info
WHERE cst_id IS NULL OR NULLIF(TRIM(cst_key),'') IS NULL OR cst_create_date IS NULL OR cst_create_date>CONVERT(date,GETDATE())
UNION ALL
SELECT 'customer duplicate IDs',COUNT(*) FROM (SELECT cst_id FROM silver.crm_cust_info GROUP BY cst_id HAVING COUNT(*)>1) q
UNION ALL
SELECT 'customer duplicate external keys',COUNT(*) FROM (SELECT cst_key FROM silver.crm_cust_info GROUP BY cst_key HAVING COUNT(*)>1) q
UNION ALL
SELECT 'customer invalid categories',COUNT(*) FROM silver.crm_cust_info
WHERE cst_marital_status NOT IN ('Single','Married','n/a') OR cst_gndr NOT IN ('Female','Male','n/a') OR cst_marital_status IS NULL OR cst_gndr IS NULL
UNION ALL
SELECT 'customer untrimmed strings',COUNT(*) FROM silver.crm_cust_info
WHERE DATALENGTH(cst_key)<>DATALENGTH(TRIM(cst_key)) OR DATALENGTH(cst_firstname)<>DATALENGTH(TRIM(cst_firstname)) OR DATALENGTH(cst_lastname)<>DATALENGTH(TRIM(cst_lastname))
UNION ALL
SELECT 'product null keys/invalid values/dates',COUNT(*) FROM silver.crm_prd_info
WHERE prd_id IS NULL OR NULLIF(TRIM(prd_key),'') IS NULL OR cat_id IS NULL
OR LEN(cat_id)<>5 OR SUBSTRING(cat_id,3,1)<>'_' OR prd_cost IS NULL OR prd_cost<0
OR prd_start_dt IS NULL OR prd_start_dt>CONVERT(date,GETDATE()) OR prd_end_dt<prd_start_dt
OR prd_line IS NULL OR prd_line NOT IN ('Mountain','Road','Other Sales','Touring','n/a')
UNION ALL
SELECT 'product duplicate row IDs',COUNT(*) FROM (SELECT prd_id FROM silver.crm_prd_info GROUP BY prd_id HAVING COUNT(*)>1) q
UNION ALL
SELECT 'product duplicate history keys',COUNT(*) FROM (SELECT prd_key,prd_start_dt FROM silver.crm_prd_info GROUP BY prd_key,prd_start_dt HAVING COUNT(*)>1) q
UNION ALL
SELECT 'product untrimmed strings',COUNT(*) FROM silver.crm_prd_info
WHERE DATALENGTH(prd_key)<>DATALENGTH(TRIM(prd_key)) OR DATALENGTH(prd_nm)<>DATALENGTH(TRIM(prd_nm));
;WITH history AS (
 SELECT *,LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt,prd_id) AS next_start
 FROM silver.crm_prd_info
)
INSERT @failures SELECT 'product continuity/latest open end',COUNT(*) FROM history
WHERE (next_start IS NULL AND prd_end_dt IS NOT NULL)
OR (next_start IS NOT NULL AND (prd_end_dt IS NULL OR prd_end_dt<>DATEADD(day,-1,next_start)));
SELECT check_name,failures FROM @failures;
IF EXISTS(SELECT 1 FROM @failures WHERE failures<>0) THROW 50701,'Silver quality checks failed.',1;
SELECT 'NULL dates on excluded null-ID customer rows',COUNT(*) FROM bronze.crm_cust_info WHERE cst_id IS NULL AND cst_create_date IS NULL;
SELECT 'Product end dates changed',COUNT(*) FROM bronze.crm_prd_info b JOIN silver.crm_prd_info s ON s.prd_id=b.prd_id
WHERE CONVERT(date,b.prd_end_dt)<>s.prd_end_dt OR (b.prd_end_dt IS NULL AND s.prd_end_dt IS NOT NULL) OR (b.prd_end_dt IS NOT NULL AND s.prd_end_dt IS NULL);
PRINT 'PASS: all 10 independent quality checks returned zero failures.';
