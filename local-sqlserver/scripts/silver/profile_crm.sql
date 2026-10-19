SET NOCOUNT ON;
SELECT DB_NAME() AS database_name, SERVERPROPERTY('Edition') AS edition;
SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID('silver');
SELECT COUNT(*) AS source_rows, COUNT(DISTINCT cst_id) AS distinct_ids,
 SUM(CASE WHEN cst_id IS NULL THEN 1 ELSE 0 END) AS null_ids,
 SUM(CASE WHEN cst_create_date IS NULL THEN 1 ELSE 0 END) AS null_dates,
 SUM(CASE WHEN cst_create_date > CONVERT(date,GETDATE()) THEN 1 ELSE 0 END) AS future_dates,
 MIN(cst_create_date) AS min_date, MAX(cst_create_date) AS max_date
FROM bronze.crm_cust_info;
SELECT cst_id, COUNT(*) AS occurrences, MIN(cst_create_date) AS earliest, MAX(cst_create_date) AS latest
FROM bronze.crm_cust_info WHERE cst_id IS NOT NULL GROUP BY cst_id HAVING COUNT(*)>1;
SELECT cst_marital_status, COUNT(*) AS rows FROM bronze.crm_cust_info GROUP BY cst_marital_status;
SELECT cst_gndr, COUNT(*) AS rows FROM bronze.crm_cust_info GROUP BY cst_gndr;
SELECT COUNT(*) AS rows, COUNT(DISTINCT prd_id) AS ids, COUNT(DISTINCT prd_key) AS historical_keys,
 SUM(CASE WHEN prd_cost IS NULL THEN 1 ELSE 0 END) AS null_cost,
 SUM(CASE WHEN prd_cost < 0 THEN 1 ELSE 0 END) AS negative_cost,
 SUM(CASE WHEN prd_start_dt IS NULL THEN 1 ELSE 0 END) AS missing_start,
 SUM(CASE WHEN prd_end_dt < prd_start_dt THEN 1 ELSE 0 END) AS reversed_ranges,
 SUM(CASE WHEN prd_start_dt > GETDATE() THEN 1 ELSE 0 END) AS future_start,
 SUM(CASE WHEN prd_start_dt <> CONVERT(date,prd_start_dt) THEN 1 ELSE 0 END) AS nonmidnight_starts
FROM bronze.crm_prd_info;
SELECT prd_line, COUNT(*) AS rows FROM bronze.crm_prd_info GROUP BY prd_line;
SELECT COUNT(*) AS malformed_keys FROM bronze.crm_prd_info
WHERE prd_id IS NULL OR prd_key IS NULL OR LEN(TRIM(prd_key))<7 OR SUBSTRING(TRIM(prd_key),3,1)<>'-' OR SUBSTRING(TRIM(prd_key),6,1)<>'-';
SELECT COUNT(*) AS ambiguous_history FROM (
 SELECT SUBSTRING(TRIM(prd_key),7,50) AS k, CONVERT(date,prd_start_dt) AS d
 FROM bronze.crm_prd_info GROUP BY SUBSTRING(TRIM(prd_key),7,50),CONVERT(date,prd_start_dt) HAVING COUNT(*)>1
) q;
SELECT COUNT(*) AS category_collisions FROM (
 SELECT SUBSTRING(TRIM(prd_key),7,50) AS k FROM bronze.crm_prd_info
 GROUP BY SUBSTRING(TRIM(prd_key),7,50) HAVING COUNT(DISTINCT LEFT(TRIM(prd_key),5))>1
) q;
