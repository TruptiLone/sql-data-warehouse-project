-- Atomic, insert-only customer/product transformation. Populated targets must match.
:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition')) <> 3
 OR CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
 THROW 50600,'Expected local Developer DataWarehouse.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @customers bigint, @products bigint, @existing bigint;
 -- Hold source locks through reconciliation; this script never writes Bronze.
 SELECT @customers=COUNT_BIG(*) FROM bronze.crm_cust_info WITH (TABLOCK,HOLDLOCK);
 SELECT @products=COUNT_BIG(*) FROM bronze.crm_prd_info WITH (TABLOCK,HOLDLOCK);
 IF EXISTS (SELECT 1 FROM bronze.crm_cust_info WHERE cst_id IS NOT NULL
  AND (NULLIF(TRIM(cst_key),'') IS NULL OR TRY_CONVERT(date,cst_create_date) IS NULL
   OR cst_create_date>CONVERT(date,GETDATE())))
  THROW 50601,'Customer key/date requires review; no additional exclusions assumed.',1;

 ;WITH ranked AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC,
  CONVERT(varbinary(100),cst_key) DESC, CONVERT(varbinary(100),cst_firstname) DESC,
  CONVERT(varbinary(100),cst_lastname) DESC, CONVERT(varbinary(100),cst_marital_status) DESC,
  CONVERT(varbinary(100),cst_gndr) DESC) AS rn
 FROM bronze.crm_cust_info WHERE cst_id IS NOT NULL
 )
 SELECT cst_id,TRIM(cst_key) AS cst_key,TRIM(cst_firstname) AS cst_firstname,
 TRIM(cst_lastname) AS cst_lastname,
 CAST(CASE UPPER(TRIM(cst_marital_status)) WHEN 'S' THEN 'Single' WHEN 'M' THEN 'Married' ELSE 'n/a' END AS nvarchar(50)) AS cst_marital_status,
 CAST(CASE UPPER(TRIM(cst_gndr)) WHEN 'F' THEN 'Female' WHEN 'M' THEN 'Male' ELSE 'n/a' END AS nvarchar(50)) AS cst_gndr,
 TRY_CONVERT(date,cst_create_date) AS cst_create_date
 INTO #customers FROM ranked WHERE rn=1;

 IF EXISTS (SELECT 1 FROM bronze.crm_prd_info WHERE prd_id IS NULL
  OR NULLIF(TRIM(prd_key),'') IS NULL OR LEN(TRIM(prd_key))<7
  OR SUBSTRING(TRIM(prd_key),3,1)<>'-' OR SUBSTRING(TRIM(prd_key),6,1)<>'-'
  OR TRY_CONVERT(date,prd_start_dt) IS NULL OR prd_start_dt>GETDATE()
  OR prd_start_dt<>CONVERT(date,prd_start_dt) OR prd_cost<0)
  THROW 50602,'Product identifier, start date, or cost requires review.',1;
 IF EXISTS (SELECT prd_id FROM bronze.crm_prd_info GROUP BY prd_id HAVING COUNT(*)>1)
  THROW 50603,'Duplicate product row IDs require review.',1;
 IF EXISTS (SELECT SUBSTRING(TRIM(prd_key),7,50),CONVERT(date,prd_start_dt)
  FROM bronze.crm_prd_info GROUP BY SUBSTRING(TRIM(prd_key),7,50),CONVERT(date,prd_start_dt) HAVING COUNT(*)>1)
  THROW 50604,'Ambiguous normalized product history requires review.',1;
 IF EXISTS (SELECT SUBSTRING(TRIM(prd_key),7,50) FROM bronze.crm_prd_info
  GROUP BY SUBSTRING(TRIM(prd_key),7,50) HAVING COUNT(DISTINCT LEFT(TRIM(prd_key),5))>1)
  THROW 50605,'Normalized product key spans categories; review before loading.',1;

 ;WITH normalized AS (
 SELECT prd_id,REPLACE(LEFT(TRIM(prd_key),5),'-','_') AS cat_id,
 SUBSTRING(TRIM(prd_key),7,50) AS prd_key,TRIM(prd_nm) AS prd_nm,
 ISNULL(prd_cost,0) AS prd_cost,
 CAST(CASE UPPER(TRIM(prd_line)) WHEN 'M' THEN 'Mountain' WHEN 'R' THEN 'Road'
 WHEN 'S' THEN 'Other Sales' WHEN 'T' THEN 'Touring' ELSE 'n/a' END AS nvarchar(50)) AS prd_line,
 TRY_CONVERT(date,prd_start_dt) AS prd_start_dt FROM bronze.crm_prd_info
 )
 SELECT *,DATEADD(day,-1,LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt,prd_id)) AS prd_end_dt
 INTO #products FROM normalized;

 IF EXISTS (SELECT cst_key FROM #customers GROUP BY cst_key HAVING COUNT(*)>1)
  THROW 50606,'Duplicate normalized customer keys require review.',1;
 IF EXISTS (SELECT 1 FROM #products WHERE prd_end_dt<prd_start_dt)
  THROW 50607,'Rebuilt product date range invalid.',1;

 SELECT @existing=COUNT_BIG(*) FROM silver.crm_cust_info WITH (TABLOCKX,HOLDLOCK);
 IF @existing=0
 BEGIN
  INSERT silver.crm_cust_info(cst_id,cst_key,cst_firstname,cst_lastname,cst_marital_status,cst_gndr,cst_create_date,dwh_create_date)
  SELECT *,SYSDATETIME() FROM #customers;
  PRINT 'Inserted Silver CRM customers.';
 END
 ELSE PRINT 'Preserved existing Silver customers; validating exact expected result.';
 SELECT @existing=COUNT_BIG(*) FROM silver.crm_prd_info WITH (TABLOCKX,HOLDLOCK);
 IF @existing=0
 BEGIN
  INSERT silver.crm_prd_info(prd_id,cat_id,prd_key,prd_nm,prd_cost,prd_line,prd_start_dt,prd_end_dt,dwh_create_date)
  SELECT *,SYSDATETIME() FROM #products;
  PRINT 'Inserted Silver CRM products.';
 END
 ELSE PRINT 'Preserved existing Silver products; validating exact expected result.';

 IF (SELECT COUNT_BIG(*) FROM silver.crm_cust_info)<>(SELECT COUNT_BIG(*) FROM #customers)
 OR EXISTS (SELECT cst_id,CONVERT(varbinary(100),cst_key),CONVERT(varbinary(100),cst_firstname),CONVERT(varbinary(100),cst_lastname),CONVERT(varbinary(100),cst_marital_status),CONVERT(varbinary(100),cst_gndr),cst_create_date FROM silver.crm_cust_info EXCEPT SELECT cst_id,CONVERT(varbinary(100),cst_key),CONVERT(varbinary(100),cst_firstname),CONVERT(varbinary(100),cst_lastname),CONVERT(varbinary(100),cst_marital_status),CONVERT(varbinary(100),cst_gndr),cst_create_date FROM #customers)
 OR EXISTS (SELECT cst_id,CONVERT(varbinary(100),cst_key),CONVERT(varbinary(100),cst_firstname),CONVERT(varbinary(100),cst_lastname),CONVERT(varbinary(100),cst_marital_status),CONVERT(varbinary(100),cst_gndr),cst_create_date FROM #customers EXCEPT SELECT cst_id,CONVERT(varbinary(100),cst_key),CONVERT(varbinary(100),cst_firstname),CONVERT(varbinary(100),cst_lastname),CONVERT(varbinary(100),cst_marital_status),CONVERT(varbinary(100),cst_gndr),cst_create_date FROM silver.crm_cust_info)
  THROW 50608,'Existing or loaded crm_cust_info differs from expected transformation; no overwrite performed.',1;

 IF (SELECT COUNT_BIG(*) FROM silver.crm_prd_info)<>(SELECT COUNT_BIG(*) FROM #products)
 OR EXISTS (SELECT prd_id,CONVERT(varbinary(100),cat_id),CONVERT(varbinary(100),prd_key),CONVERT(varbinary(100),prd_nm),prd_cost,CONVERT(varbinary(100),prd_line),prd_start_dt,prd_end_dt FROM silver.crm_prd_info EXCEPT SELECT prd_id,CONVERT(varbinary(100),cat_id),CONVERT(varbinary(100),prd_key),CONVERT(varbinary(100),prd_nm),prd_cost,CONVERT(varbinary(100),prd_line),prd_start_dt,prd_end_dt FROM #products)
 OR EXISTS (SELECT prd_id,CONVERT(varbinary(100),cat_id),CONVERT(varbinary(100),prd_key),CONVERT(varbinary(100),prd_nm),prd_cost,CONVERT(varbinary(100),prd_line),prd_start_dt,prd_end_dt FROM #products EXCEPT SELECT prd_id,CONVERT(varbinary(100),cat_id),CONVERT(varbinary(100),prd_key),CONVERT(varbinary(100),prd_nm),prd_cost,CONVERT(varbinary(100),prd_line),prd_start_dt,prd_end_dt FROM silver.crm_prd_info)
  THROW 50608,'Existing or loaded crm_prd_info differs from expected transformation; no overwrite performed.',1;

 IF EXISTS (SELECT cst_id FROM silver.crm_cust_info GROUP BY cst_id HAVING cst_id IS NULL OR COUNT(*)>1)
 OR EXISTS (SELECT prd_id FROM silver.crm_prd_info GROUP BY prd_id HAVING prd_id IS NULL OR COUNT(*)>1)
 OR EXISTS (SELECT 1 FROM silver.crm_cust_info WHERE dwh_create_date IS NULL)
 OR EXISTS (SELECT 1 FROM silver.crm_prd_info WHERE dwh_create_date IS NULL)
  THROW 50609,'Silver business-key or audit-timestamp validation failed.',1;
 IF (SELECT COUNT(*) FROM #customers)<>(SELECT COUNT(DISTINCT cst_id) FROM bronze.crm_cust_info)
 OR (SELECT COUNT(*) FROM #products)<>@products
  THROW 50610,'Bronze-to-Silver reconciliation failed.',1;
 SELECT 'CUSTOMERS' AS dataset,@customers AS source_rows,
  (SELECT COUNT(*) FROM bronze.crm_cust_info WHERE cst_id IS NULL) AS excluded_null_ids,
  (SELECT COUNT(cst_id)-COUNT(DISTINCT cst_id) FROM bronze.crm_cust_info) AS merged_duplicate_occurrences,
  (SELECT COUNT(*) FROM silver.crm_cust_info) AS silver_rows;
 SELECT 'PRODUCTS' AS dataset,@products AS source_rows,
  (SELECT COUNT(*) FROM silver.crm_prd_info) AS silver_rows,
  (SELECT COUNT(*) FROM bronze.crm_prd_info WHERE prd_end_dt<prd_start_dt) AS source_reversed_ranges,
  (SELECT COUNT(*) FROM silver.crm_prd_info WHERE prd_end_dt IS NULL) AS current_versions,
  (SELECT COUNT(*) FROM silver.crm_prd_info WHERE prd_end_dt IS NOT NULL) AS historical_versions;
 COMMIT TRANSACTION;
 PRINT 'PASS: exact transformed values, counts, keys, dates, and audit timestamps; both tables committed.';
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
