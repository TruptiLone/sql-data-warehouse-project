-- Read-only assertions plus explicitly reported unresolved source-history gaps.
:ON ERROR EXIT
SET NOCOUNT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 OR CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
 THROW 51020,'Expected local Developer DataWarehouse.',1;
DECLARE @checks TABLE(check_name varchar(100),failures bigint);
INSERT @checks
SELECT 'source/target count difference',ABS((SELECT COUNT_BIG(*) FROM bronze.crm_sales_details)-(SELECT COUNT_BIG(*) FROM silver.crm_sales_details))
UNION ALL SELECT 'null/blank identifiers',COUNT(*) FROM silver.crm_sales_details WHERE NULLIF(TRIM(sls_ord_num),'') IS NULL OR NULLIF(TRIM(sls_prd_key),'') IS NULL OR sls_cust_id IS NULL
UNION ALL SELECT 'duplicate order/product groups',COUNT(*) FROM (SELECT sls_ord_num,sls_prd_key FROM silver.crm_sales_details GROUP BY sls_ord_num,sls_prd_key HAVING COUNT(*)>1) q
UNION ALL SELECT 'invalid quantities',COUNT(*) FROM silver.crm_sales_details WHERE sls_quantity IS NULL OR sls_quantity<=0
UNION ALL SELECT 'invalid/missing amounts',COUNT(*) FROM silver.crm_sales_details WHERE sls_price IS NULL OR sls_price<=0 OR sls_sales IS NULL OR sls_sales<=0
UNION ALL SELECT 'sales quantity price discrepancies',COUNT(*) FROM silver.crm_sales_details WHERE CONVERT(bigint,sls_sales)<>CONVERT(bigint,sls_quantity)*sls_price
UNION ALL SELECT 'chronology failures',COUNT(*) FROM silver.crm_sales_details WHERE sls_order_dt>sls_ship_dt OR sls_order_dt>sls_due_dt OR sls_ship_dt>sls_due_dt
UNION ALL SELECT 'future dates',COUNT(*) FROM silver.crm_sales_details WHERE sls_order_dt>CONVERT(date,GETDATE()) OR sls_ship_dt>CONVERT(date,GETDATE()) OR sls_due_dt>CONVERT(date,GETDATE())
UNION ALL SELECT 'missing customer reference',COUNT(*) FROM silver.crm_sales_details s WHERE NOT EXISTS(SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_id=s.sls_cust_id)
UNION ALL SELECT 'missing product key reference',COUNT(*) FROM silver.crm_sales_details s WHERE NOT EXISTS(SELECT 1 FROM silver.crm_prd_info p WHERE p.prd_key=s.sls_prd_key)
UNION ALL SELECT 'missing warehouse timestamps',COUNT(*) FROM silver.crm_sales_details WHERE dwh_create_date IS NULL
UNION ALL SELECT 'untrimmed keys',COUNT(*) FROM silver.crm_sales_details WHERE DATALENGTH(sls_ord_num)<>DATALENGTH(TRIM(sls_ord_num)) OR DATALENGTH(sls_prd_key)<>DATALENGTH(TRIM(sls_prd_key));
-- EXISTS avoids multiplying rows when a product has multiple historical versions.
INSERT @checks SELECT 'ambiguous dated product-version matches',COUNT(*) FROM silver.crm_sales_details s
WHERE (SELECT COUNT(*) FROM silver.crm_prd_info p WHERE p.prd_key=s.sls_prd_key AND s.sls_order_dt>=p.prd_start_dt AND (s.sls_order_dt<=p.prd_end_dt OR p.prd_end_dt IS NULL))>1;
-- Date conversion correctness, including NULLs, is independent of row order.
INSERT @checks SELECT 'date conversion mismatch',COUNT(*) FROM bronze.crm_sales_details b JOIN silver.crm_sales_details s
ON s.sls_ord_num=TRIM(b.sls_ord_num) AND s.sls_prd_key=TRIM(b.sls_prd_key)
CROSS APPLY(VALUES(b.sls_order_dt,s.sls_order_dt),(b.sls_ship_dt,s.sls_ship_dt),(b.sls_due_dt,s.sls_due_dt)) d(raw_date,clean_date)
CROSS APPLY(SELECT CASE WHEN LEN(CONVERT(varchar(11),raw_date))=8 THEN TRY_CONVERT(date,CONVERT(varchar(11),NULLIF(raw_date,0)),112) END AS expected_date) e
WHERE EXISTS(SELECT clean_date EXCEPT SELECT expected_date);
SELECT check_name,failures FROM @checks;
IF EXISTS(SELECT 1 FROM @checks WHERE failures<>0) THROW 51021,'Sales quality assertion failed.',1;
SELECT 'unresolved unknown order dates',COUNT(*) FROM silver.crm_sales_details WHERE sls_order_dt IS NULL;
SELECT 'unknown ship/due dates',COUNT(*) FROM silver.crm_sales_details WHERE sls_ship_dt IS NULL OR sls_due_dt IS NULL;
SELECT 'dated sales before first product version',COUNT(*) FROM silver.crm_sales_details s
WHERE s.sls_order_dt<(SELECT MIN(prd_start_dt) FROM silver.crm_prd_info p WHERE p.prd_key=s.sls_prd_key);
SELECT 'dated sales with exactly one matching version',COUNT(*) FROM silver.crm_sales_details s
WHERE (SELECT COUNT(*) FROM silver.crm_prd_info p WHERE p.prd_key=s.sls_prd_key AND s.sls_order_dt>=p.prd_start_dt AND (s.sls_order_dt<=p.prd_end_dt OR p.prd_end_dt IS NULL))=1;
SELECT 'sales amount repairs',COUNT(*) FROM bronze.crm_sales_details b JOIN silver.crm_sales_details s ON s.sls_ord_num=b.sls_ord_num AND s.sls_prd_key=b.sls_prd_key WHERE b.sls_sales IS NULL OR b.sls_sales<>s.sls_sales;
SELECT 'unit price repairs',COUNT(*) FROM bronze.crm_sales_details b JOIN silver.crm_sales_details s ON s.sls_ord_num=b.sls_ord_num AND s.sls_prd_key=b.sls_prd_key WHERE b.sls_price IS NULL OR b.sls_price<>s.sls_price;
SELECT 'before/after known sales totals', (SELECT SUM(CONVERT(bigint,sls_sales)) FROM bronze.crm_sales_details),(SELECT SUM(CONVERT(bigint,sls_sales)) FROM silver.crm_sales_details);
PRINT 'PASS: 14 sales quality assertions; unresolved source-date/history warnings reported separately.';
