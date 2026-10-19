-- Source-only preview. run_customers.py injects the exact view SELECT, never its DDL.
:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 OR CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
 OR ISNULL(CONVERT(varchar(48),CONNECTIONPROPERTY('local_net_address')),'')<>'127.0.0.1'
 THROW 51700,'Expected verified local Developer DataWarehouse over loopback.',1;
IF OBJECT_ID('gold.dim_customers') IS NOT NULL AND OBJECT_ID('gold.dim_customers','V') IS NULL
 THROW 51701,'Gold customer name conflict; stop for approval.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @n bigint;
 SELECT @n=COUNT_BIG(*) FROM silver.crm_cust_info WITH(TABLOCK,HOLDLOCK);
 SELECT @n=COUNT_BIG(*) FROM silver.erp_cust_az12 WITH(TABLOCK,HOLDLOCK);
 SELECT @n=COUNT_BIG(*) FROM silver.erp_loc_a101 WITH(TABLOCK,HOLDLOCK);
 IF EXISTS(SELECT cst_id FROM silver.crm_cust_info GROUP BY cst_id HAVING COUNT(*)>1 OR cst_id IS NULL)
 OR EXISTS(SELECT cst_key FROM silver.crm_cust_info GROUP BY cst_key HAVING COUNT(*)>1 OR NULLIF(TRIM(cst_key),'') IS NULL)
 OR EXISTS(SELECT cid FROM silver.erp_cust_az12 GROUP BY cid HAVING COUNT(*)>1 OR NULLIF(TRIM(cid),'') IS NULL)
 OR EXISTS(SELECT cid FROM silver.erp_loc_a101 GROUP BY cid HAVING COUNT(*)>1 OR NULLIF(TRIM(cid),'') IS NULL)
 THROW 51702,'Nonunique or missing integration keys.',1;
 SELECT * INTO #preview FROM (
$(customer_select)
 ) AS proposed;
 SELECT 'object_status' AS report,COALESCE((SELECT type_desc FROM sys.objects WHERE object_id=OBJECT_ID('gold.dim_customers')),'ABSENT') AS object_type;
 SELECT 'preview' AS report,COUNT_BIG(*) AS customers,COUNT(DISTINCT customer_id) AS distinct_customer_ids,
 COUNT(DISTINCT customer_key) AS distinct_customer_keys,
 SUM(CASE WHEN gender='n/a' THEN 1 ELSE 0 END) AS unknown_genders,
 SUM(CASE WHEN birthdate IS NULL THEN 1 ELSE 0 END) AS null_birthdates,
 SUM(CASE WHEN country='n/a' THEN 1 ELSE 0 END) AS unknown_countries FROM #preview;
 SELECT 'gender_audit' AS report,
 SUM(CASE WHEN LOWER(TRIM(ci.cst_gndr)) IN('male','female') AND LOWER(TRIM(ca.gen)) IN('male','female') AND LOWER(TRIM(ci.cst_gndr))<>LOWER(TRIM(ca.gen)) THEN 1 ELSE 0 END) AS conflicts,
 SUM(CASE WHEN LOWER(TRIM(COALESCE(ci.cst_gndr,''))) IN('','n/a') AND LOWER(TRIM(ca.gen)) IN('male','female') THEN 1 ELSE 0 END) AS erp_enriched,
 SUM(CASE WHEN LOWER(TRIM(ci.cst_gndr)) IN('male','female') AND LOWER(p.gender)<>LOWER(TRIM(ci.cst_gndr)) THEN 1 ELSE 0 END) AS crm_precedence_failures
 FROM silver.crm_cust_info ci LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key=ca.cid JOIN #preview p ON p.customer_id=ci.cst_id;
 SELECT 'coverage' AS report,
 (SELECT COUNT(*) FROM silver.crm_cust_info ci WHERE NOT EXISTS(SELECT 1 FROM #preview p WHERE p.customer_id=ci.cst_id)) AS missing_crm,
 (SELECT COUNT(*) FROM silver.crm_cust_info ci WHERE NOT EXISTS(SELECT 1 FROM silver.erp_cust_az12 e WHERE e.cid=ci.cst_key)) AS missing_erp_demographics,
 (SELECT COUNT(*) FROM silver.crm_cust_info ci WHERE NOT EXISTS(SELECT 1 FROM silver.erp_loc_a101 e WHERE e.cid=ci.cst_key)) AS missing_erp_location;
 SELECT gender,COUNT(*) AS customers FROM #preview GROUP BY gender;
 IF (SELECT COUNT(*) FROM #preview)<>(SELECT COUNT(*) FROM silver.crm_cust_info)
 OR EXISTS(SELECT customer_id FROM #preview GROUP BY customer_id HAVING COUNT(*)>1)
 OR EXISTS(SELECT customer_key FROM #preview GROUP BY customer_key HAVING COUNT(*)>1)
 OR EXISTS(SELECT cst_id FROM silver.crm_cust_info EXCEPT SELECT customer_id FROM #preview)
 THROW 51703,'Preview grain or CRM coverage failed.',1;
 IF EXISTS(SELECT 1 FROM silver.crm_cust_info WHERE LOWER(TRIM(COALESCE(cst_gndr,''))) NOT IN('male','female','','n/a'))
 OR EXISTS(SELECT 1 FROM silver.erp_cust_az12 WHERE LOWER(TRIM(COALESCE(gen,''))) NOT IN('male','female','','n/a'))
 THROW 51704,'Unexpected source gender domain; review needed.',1;
 COMMIT TRANSACTION;
 PRINT 'PASS: exact proposed SELECT preview; no persistent DDL or data changes.';
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
