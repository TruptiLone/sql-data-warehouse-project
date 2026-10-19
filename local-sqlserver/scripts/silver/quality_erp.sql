:ON ERROR EXIT
SET NOCOUNT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 THROW 51210,'Expected local DataWarehouse.',1;
SELECT 'birthdates retained over 100 years old',COUNT(*),MIN(bdate),MAX(bdate) FROM silver.erp_cust_az12 WHERE bdate<DATEADD(year,-100,CONVERT(date,GETDATE()));
SELECT 'birthdate NULLs',COUNT(*) FROM silver.erp_cust_az12 WHERE bdate IS NULL;
SELECT 'gender distribution',gen,COUNT(*) FROM silver.erp_cust_az12 GROUP BY gen ORDER BY gen;
SELECT 'country distribution',cntry,COUNT(*) FROM silver.erp_loc_a101 GROUP BY cntry ORDER BY cntry;
SELECT 'customer unmatched',COUNT(*) FROM silver.erp_cust_az12 e WHERE NOT EXISTS(SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_key=e.cid);
SELECT 'location unmatched',COUNT(*) FROM silver.erp_loc_a101 e WHERE NOT EXISTS(SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_key=e.cid);
SELECT 'CRM without ERP customer',COUNT(*) FROM silver.crm_cust_info c WHERE NOT EXISTS(SELECT 1 FROM silver.erp_cust_az12 e WHERE e.cid=c.cst_key);
SELECT 'CRM without ERP location',COUNT(*) FROM silver.crm_cust_info c WHERE NOT EXISTS(SELECT 1 FROM silver.erp_loc_a101 e WHERE e.cid=c.cst_key);
SELECT 'ERP category without CRM',e.id,e.cat,e.subcat FROM silver.erp_px_cat_g1v2 e WHERE NOT EXISTS(SELECT 1 FROM silver.crm_prd_info p WHERE p.cat_id=e.id);
SELECT 'CRM category without ERP',p.cat_id,COUNT(*) AS product_versions,COUNT(DISTINCT prd_key) AS product_keys FROM silver.crm_prd_info p WHERE NOT EXISTS(SELECT 1 FROM silver.erp_px_cat_g1v2 e WHERE e.id=p.cat_id) GROUP BY p.cat_id;
IF EXISTS(SELECT 1 FROM silver.erp_cust_az12 WHERE cid IS NULL OR gen IS NULL OR gen NOT IN ('Male','Female','n/a') OR bdate>CONVERT(date,GETDATE()) OR DATALENGTH(cid)<>DATALENGTH(TRIM(cid)))
 OR EXISTS(SELECT 1 FROM silver.erp_loc_a101 WHERE cid IS NULL OR cid LIKE '%-%' OR cntry IS NULL OR NULLIF(TRIM(cntry),'') IS NULL OR cntry IN ('D','DE','US','USA') OR DATALENGTH(cntry)<>DATALENGTH(TRIM(cntry)))
 THROW 51211,'ERP customer/location normalization failure.',1;
IF EXISTS(SELECT 1 FROM silver.erp_px_cat_g1v2 WHERE NULLIF(TRIM(id),'') IS NULL OR NULLIF(TRIM(cat),'') IS NULL OR NULLIF(TRIM(subcat),'') IS NULL OR maintenance IS NULL OR maintenance NOT IN ('Yes','No')
 OR DATALENGTH(id)<>DATALENGTH(TRIM(id)) OR DATALENGTH(cat)<>DATALENGTH(TRIM(cat)) OR DATALENGTH(subcat)<>DATALENGTH(TRIM(subcat)) OR DATALENGTH(maintenance)<>DATALENGTH(TRIM(maintenance)))
 OR EXISTS(SELECT subcat FROM silver.erp_px_cat_g1v2 GROUP BY subcat HAVING COUNT(DISTINCT cat)>1)
 OR EXISTS(SELECT LEFT(id,2) FROM silver.erp_px_cat_g1v2 GROUP BY LEFT(id,2) HAVING COUNT(DISTINCT cat)>1)
 THROW 51212,'ERP category quality failure.',1;
SELECT 'category distribution',cat,COUNT(*) FROM silver.erp_px_cat_g1v2 GROUP BY cat;
SELECT 'maintenance distribution',maintenance,COUNT(*) FROM silver.erp_px_cat_g1v2 GROUP BY maintenance;
PRINT 'PASS: normalization, date, category consistency checks. Integration gaps above are reported, not silently repaired.';

SELECT 'erp_cust_az12' AS dataset,(SELECT COUNT_BIG(*) FROM bronze.erp_cust_az12) AS bronze_rows,
 COUNT_BIG(*) AS silver_rows,COUNT(DISTINCT cid) AS distinct_ids,
 SUM(CASE WHEN NULLIF(TRIM(cid),'') IS NULL THEN 1 ELSE 0 END) AS null_or_empty_ids
FROM silver.erp_cust_az12;
IF (SELECT COUNT_BIG(*) FROM bronze.erp_cust_az12)<>(SELECT COUNT_BIG(*) FROM silver.erp_cust_az12)
 OR EXISTS(SELECT 1 FROM silver.erp_cust_az12 WHERE NULLIF(TRIM(cid),'') IS NULL OR dwh_create_date IS NULL)
 OR EXISTS(SELECT cid FROM silver.erp_cust_az12 GROUP BY cid HAVING COUNT(*)>1)
 THROW 51213,'ERP count, identifier, or audit timestamp quality failure.',1;

SELECT 'erp_loc_a101' AS dataset,(SELECT COUNT_BIG(*) FROM bronze.erp_loc_a101) AS bronze_rows,
 COUNT_BIG(*) AS silver_rows,COUNT(DISTINCT cid) AS distinct_ids,
 SUM(CASE WHEN NULLIF(TRIM(cid),'') IS NULL THEN 1 ELSE 0 END) AS null_or_empty_ids
FROM silver.erp_loc_a101;
IF (SELECT COUNT_BIG(*) FROM bronze.erp_loc_a101)<>(SELECT COUNT_BIG(*) FROM silver.erp_loc_a101)
 OR EXISTS(SELECT 1 FROM silver.erp_loc_a101 WHERE NULLIF(TRIM(cid),'') IS NULL OR dwh_create_date IS NULL)
 OR EXISTS(SELECT cid FROM silver.erp_loc_a101 GROUP BY cid HAVING COUNT(*)>1)
 THROW 51213,'ERP count, identifier, or audit timestamp quality failure.',1;

SELECT 'erp_px_cat_g1v2' AS dataset,(SELECT COUNT_BIG(*) FROM bronze.erp_px_cat_g1v2) AS bronze_rows,
 COUNT_BIG(*) AS silver_rows,COUNT(DISTINCT id) AS distinct_ids,
 SUM(CASE WHEN NULLIF(TRIM(id),'') IS NULL THEN 1 ELSE 0 END) AS null_or_empty_ids
FROM silver.erp_px_cat_g1v2;
IF (SELECT COUNT_BIG(*) FROM bronze.erp_px_cat_g1v2)<>(SELECT COUNT_BIG(*) FROM silver.erp_px_cat_g1v2)
 OR EXISTS(SELECT 1 FROM silver.erp_px_cat_g1v2 WHERE NULLIF(TRIM(id),'') IS NULL OR dwh_create_date IS NULL)
 OR EXISTS(SELECT id FROM silver.erp_px_cat_g1v2 GROUP BY id HAVING COUNT(*)>1)
 THROW 51213,'ERP count, identifier, or audit timestamp quality failure.',1;
PRINT 'PASS: all three ERP counts, distinct IDs, required IDs and timestamps.';
