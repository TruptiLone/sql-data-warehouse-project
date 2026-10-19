:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 OR CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
 THROW 51201,'Expected local Developer DataWarehouse.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @rows bigint,@as_of date=CONVERT(date,GETDATE());
SELECT @rows=COUNT_BIG(*) FROM bronze.erp_cust_az12 WITH(TABLOCK,HOLDLOCK);
SELECT @rows=COUNT_BIG(*) FROM silver.erp_cust_az12 WITH(TABLOCKX,HOLDLOCK);
SELECT @rows=COUNT_BIG(*) FROM bronze.erp_loc_a101 WITH(TABLOCK,HOLDLOCK);
SELECT @rows=COUNT_BIG(*) FROM silver.erp_loc_a101 WITH(TABLOCKX,HOLDLOCK);
SELECT @rows=COUNT_BIG(*) FROM bronze.erp_px_cat_g1v2 WITH(TABLOCK,HOLDLOCK);
SELECT @rows=COUNT_BIG(*) FROM silver.erp_px_cat_g1v2 WITH(TABLOCKX,HOLDLOCK);
SELECT @rows=COUNT_BIG(*) FROM silver.crm_cust_info WITH(TABLOCK,HOLDLOCK);
SELECT @rows=COUNT_BIG(*) FROM silver.crm_prd_info WITH(TABLOCK,HOLDLOCK);
;WITH normalized AS (
 SELECT CASE WHEN LEFT(TRIM(cid),3)='NAS' THEN SUBSTRING(TRIM(cid),4,50) ELSE TRIM(cid) END AS cid,
 CASE WHEN TRY_CONVERT(date,bdate)>@as_of THEN NULL ELSE TRY_CONVERT(date,bdate) END AS bdate,
 CAST(CASE UPPER(TRIM(gen)) WHEN 'M' THEN 'Male' WHEN 'MALE' THEN 'Male' WHEN 'F' THEN 'Female' WHEN 'FEMALE' THEN 'Female' ELSE 'n/a' END AS nvarchar(50)) AS gen
 FROM bronze.erp_cust_az12
) SELECT * INTO #erp_cust_az12 FROM normalized;
;WITH normalized AS (
 SELECT REPLACE(TRIM(cid),'-','') AS cid,
 CAST(CASE WHEN UPPER(TRIM(cntry)) IN ('D','DE') THEN 'Germany'
 WHEN UPPER(TRIM(cntry)) IN ('US','USA') THEN 'United States'
 WHEN NULLIF(TRIM(cntry),'') IS NULL THEN 'n/a' ELSE TRIM(cntry) END AS nvarchar(50)) AS cntry
 FROM bronze.erp_loc_a101
) SELECT * INTO #erp_loc_a101 FROM normalized;
-- Profile shows no cleaning required; preserve all category attributes exactly.
SELECT id,cat,subcat,maintenance INTO #erp_px_cat_g1v2 FROM bronze.erp_px_cat_g1v2;

IF EXISTS(SELECT 1 FROM #erp_cust_az12 WHERE NULLIF(TRIM(cid),'') IS NULL)
 OR EXISTS(SELECT cid FROM #erp_cust_az12 GROUP BY cid HAVING COUNT(*)>1)
 THROW 51205,'Missing/duplicate transformed ERP IDs require review; no exclusion allowed.',1;
IF NOT EXISTS(SELECT 1 FROM silver.erp_cust_az12)
BEGIN
 INSERT silver.erp_cust_az12(cid,bdate,gen,dwh_create_date) SELECT *,SYSDATETIME() FROM #erp_cust_az12;
 PRINT 'Inserted silver.erp_cust_az12';
END
ELSE PRINT 'Preserved silver.erp_cust_az12; checking expected values.';
IF (SELECT COUNT_BIG(*) FROM silver.erp_cust_az12)<>(SELECT COUNT_BIG(*) FROM bronze.erp_cust_az12)
 OR EXISTS(SELECT CONVERT(varbinary(100),cid),bdate,CONVERT(varbinary(100),gen) FROM silver.erp_cust_az12 EXCEPT SELECT CONVERT(varbinary(100),cid),bdate,CONVERT(varbinary(100),gen) FROM #erp_cust_az12)
 OR EXISTS(SELECT CONVERT(varbinary(100),cid),bdate,CONVERT(varbinary(100),gen) FROM #erp_cust_az12 EXCEPT SELECT CONVERT(varbinary(100),cid),bdate,CONVERT(varbinary(100),gen) FROM silver.erp_cust_az12)
 OR EXISTS(SELECT cid FROM silver.erp_cust_az12 GROUP BY cid HAVING COUNT(*)>1)
 OR EXISTS(SELECT 1 FROM silver.erp_cust_az12 WHERE dwh_create_date IS NULL)
 THROW 51206,'ERP result differs from source transformation. Existing rows preserved; review required.',1;
SELECT 'erp_cust_az12' AS dataset,(SELECT COUNT(*) FROM bronze.erp_cust_az12) AS source_rows,COUNT(*) AS silver_rows,COUNT(DISTINCT cid) AS distinct_ids FROM silver.erp_cust_az12;

IF EXISTS(SELECT 1 FROM #erp_loc_a101 WHERE NULLIF(TRIM(cid),'') IS NULL)
 OR EXISTS(SELECT cid FROM #erp_loc_a101 GROUP BY cid HAVING COUNT(*)>1)
 THROW 51205,'Missing/duplicate transformed ERP IDs require review; no exclusion allowed.',1;
IF NOT EXISTS(SELECT 1 FROM silver.erp_loc_a101)
BEGIN
 INSERT silver.erp_loc_a101(cid,cntry,dwh_create_date) SELECT *,SYSDATETIME() FROM #erp_loc_a101;
 PRINT 'Inserted silver.erp_loc_a101';
END
ELSE PRINT 'Preserved silver.erp_loc_a101; checking expected values.';
IF (SELECT COUNT_BIG(*) FROM silver.erp_loc_a101)<>(SELECT COUNT_BIG(*) FROM bronze.erp_loc_a101)
 OR EXISTS(SELECT CONVERT(varbinary(100),cid),CONVERT(varbinary(100),cntry) FROM silver.erp_loc_a101 EXCEPT SELECT CONVERT(varbinary(100),cid),CONVERT(varbinary(100),cntry) FROM #erp_loc_a101)
 OR EXISTS(SELECT CONVERT(varbinary(100),cid),CONVERT(varbinary(100),cntry) FROM #erp_loc_a101 EXCEPT SELECT CONVERT(varbinary(100),cid),CONVERT(varbinary(100),cntry) FROM silver.erp_loc_a101)
 OR EXISTS(SELECT cid FROM silver.erp_loc_a101 GROUP BY cid HAVING COUNT(*)>1)
 OR EXISTS(SELECT 1 FROM silver.erp_loc_a101 WHERE dwh_create_date IS NULL)
 THROW 51206,'ERP result differs from source transformation. Existing rows preserved; review required.',1;
SELECT 'erp_loc_a101' AS dataset,(SELECT COUNT(*) FROM bronze.erp_loc_a101) AS source_rows,COUNT(*) AS silver_rows,COUNT(DISTINCT cid) AS distinct_ids FROM silver.erp_loc_a101;

IF EXISTS(SELECT 1 FROM #erp_px_cat_g1v2 WHERE NULLIF(TRIM(id),'') IS NULL)
 OR EXISTS(SELECT id FROM #erp_px_cat_g1v2 GROUP BY id HAVING COUNT(*)>1)
 THROW 51205,'Missing/duplicate transformed ERP IDs require review; no exclusion allowed.',1;
IF NOT EXISTS(SELECT 1 FROM silver.erp_px_cat_g1v2)
BEGIN
 INSERT silver.erp_px_cat_g1v2(id,cat,subcat,maintenance,dwh_create_date) SELECT *,SYSDATETIME() FROM #erp_px_cat_g1v2;
 PRINT 'Inserted silver.erp_px_cat_g1v2';
END
ELSE PRINT 'Preserved silver.erp_px_cat_g1v2; checking expected values.';
IF (SELECT COUNT_BIG(*) FROM silver.erp_px_cat_g1v2)<>(SELECT COUNT_BIG(*) FROM bronze.erp_px_cat_g1v2)
 OR EXISTS(SELECT CONVERT(varbinary(100),id),CONVERT(varbinary(100),cat),CONVERT(varbinary(100),subcat),CONVERT(varbinary(100),maintenance) FROM silver.erp_px_cat_g1v2 EXCEPT SELECT CONVERT(varbinary(100),id),CONVERT(varbinary(100),cat),CONVERT(varbinary(100),subcat),CONVERT(varbinary(100),maintenance) FROM #erp_px_cat_g1v2)
 OR EXISTS(SELECT CONVERT(varbinary(100),id),CONVERT(varbinary(100),cat),CONVERT(varbinary(100),subcat),CONVERT(varbinary(100),maintenance) FROM #erp_px_cat_g1v2 EXCEPT SELECT CONVERT(varbinary(100),id),CONVERT(varbinary(100),cat),CONVERT(varbinary(100),subcat),CONVERT(varbinary(100),maintenance) FROM silver.erp_px_cat_g1v2)
 OR EXISTS(SELECT id FROM silver.erp_px_cat_g1v2 GROUP BY id HAVING COUNT(*)>1)
 OR EXISTS(SELECT 1 FROM silver.erp_px_cat_g1v2 WHERE dwh_create_date IS NULL)
 THROW 51206,'ERP result differs from source transformation. Existing rows preserved; review required.',1;
SELECT 'erp_px_cat_g1v2' AS dataset,(SELECT COUNT(*) FROM bronze.erp_px_cat_g1v2) AS source_rows,COUNT(*) AS silver_rows,COUNT(DISTINCT id) AS distinct_ids FROM silver.erp_px_cat_g1v2;

IF EXISTS(SELECT 1 FROM silver.erp_cust_az12 WHERE gen NOT IN ('Male','Female','n/a') OR gen IS NULL OR bdate>@as_of)
 THROW 51207,'Invalid ERP customer standardized values.',1;
PRINT 'PASS: ERP source reconciliation and exact transformed values.';
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
