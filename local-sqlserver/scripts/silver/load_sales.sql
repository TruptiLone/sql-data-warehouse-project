-- Local-only insert-once transformation. See SALES.md for amount assumptions.
:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 OR CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
 THROW 50900,'Expected local Developer DataWarehouse.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @source bigint,@existing bigint,@lock_count bigint;
 SELECT @source=COUNT_BIG(*) FROM bronze.crm_sales_details WITH (TABLOCK,HOLDLOCK);
 SELECT @lock_count=COUNT_BIG(*) FROM silver.crm_cust_info WITH (TABLOCK,HOLDLOCK);
 SELECT @lock_count=COUNT_BIG(*) FROM silver.crm_prd_info WITH (TABLOCK,HOLDLOCK);
 SELECT @existing=COUNT_BIG(*) FROM silver.crm_sales_details WITH (TABLOCKX,HOLDLOCK);
 IF EXISTS (SELECT 1 FROM bronze.crm_sales_details WHERE sls_quantity IS NULL OR sls_quantity<=0
  OR NULLIF(TRIM(sls_ord_num),'') IS NULL OR NULLIF(TRIM(sls_prd_key),'') IS NULL OR sls_cust_id IS NULL)
  THROW 50901,'Unusable source identifiers or quantities: review required, no rows excluded.',1;
 -- If price is unusable, require an exact positive quotient compatible with INT.
 IF EXISTS (SELECT 1 FROM bronze.crm_sales_details WHERE (sls_price IS NULL OR sls_price<=0)
  AND (sls_sales IS NULL OR sls_sales<=0 OR CONVERT(bigint,sls_sales)%NULLIF(sls_quantity,0)<>0))
  THROW 50902,'Amount cannot be repaired without guessing or rounding; review required.',1;
 IF EXISTS (SELECT 1 FROM bronze.crm_sales_details WHERE sls_price>0
  AND TRY_CONVERT(int,CONVERT(bigint,sls_price)*sls_quantity) IS NULL)
  THROW 50903,'Derived sales would overflow original INT type; review required.',1;

 ;WITH normalized AS (
 SELECT TRIM(sls_ord_num) AS sls_ord_num,TRIM(sls_prd_key) AS sls_prd_key,sls_cust_id,
 CASE WHEN LEN(CONVERT(varchar(11),sls_order_dt))=8 THEN TRY_CONVERT(date,CONVERT(varchar(11),NULLIF(sls_order_dt,0)),112) END AS sls_order_dt,
 CASE WHEN LEN(CONVERT(varchar(11),sls_ship_dt))=8 THEN TRY_CONVERT(date,CONVERT(varchar(11),NULLIF(sls_ship_dt,0)),112) END AS sls_ship_dt,
 CASE WHEN LEN(CONVERT(varchar(11),sls_due_dt))=8 THEN TRY_CONVERT(date,CONVERT(varchar(11),NULLIF(sls_due_dt,0)),112) END AS sls_due_dt,
 CASE WHEN sls_price>0 THEN TRY_CONVERT(int,CONVERT(bigint,sls_price)*sls_quantity) ELSE sls_sales END AS sls_sales,
 sls_quantity,
 CASE WHEN sls_price>0 THEN sls_price ELSE TRY_CONVERT(int,CONVERT(bigint,sls_sales)/NULLIF(sls_quantity,0)) END AS sls_price
 FROM bronze.crm_sales_details
 ) SELECT * INTO #expected_sales FROM normalized;
 IF EXISTS (SELECT sls_ord_num,sls_prd_key FROM #expected_sales GROUP BY sls_ord_num,sls_prd_key HAVING COUNT(*)>1)
  THROW 50904,'Order/product key is not unique; preserve source and review, never deduplicate silently.',1;
 IF EXISTS (SELECT 1 FROM #expected_sales s WHERE
  NOT EXISTS(SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_id=s.sls_cust_id)
  OR NOT EXISTS(SELECT 1 FROM silver.crm_prd_info p WHERE p.prd_key=s.sls_prd_key))
  THROW 50905,'Missing customer/product key reference requires review.',1;
 IF EXISTS (SELECT 1 FROM #expected_sales WHERE sls_sales IS NULL OR sls_price IS NULL
  OR sls_sales<=0 OR sls_price<=0 OR CONVERT(bigint,sls_sales)<>CONVERT(bigint,sls_quantity)*sls_price
  OR sls_order_dt>sls_ship_dt OR sls_order_dt>sls_due_dt OR sls_ship_dt>sls_due_dt
  OR sls_order_dt>CONVERT(date,GETDATE()) OR sls_ship_dt>CONVERT(date,GETDATE()) OR sls_due_dt>CONVERT(date,GETDATE()))
  THROW 50906,'Unresolved amount or chronological anomaly requires review.',1;
 IF @existing=0
 BEGIN
  INSERT silver.crm_sales_details(sls_ord_num,sls_prd_key,sls_cust_id,sls_order_dt,sls_ship_dt,sls_due_dt,sls_sales,sls_quantity,sls_price,dwh_create_date)
  SELECT *,SYSDATETIME() FROM #expected_sales;
  PRINT 'Inserted Silver sales; no source rows excluded.';
 END
 ELSE PRINT 'Preserved populated Silver sales; validating expected values without writes.';

 IF (SELECT COUNT_BIG(*) FROM silver.crm_sales_details)<>@source
 OR EXISTS(SELECT CONVERT(varbinary(100),sls_ord_num),CONVERT(varbinary(100),sls_prd_key),sls_cust_id,sls_order_dt,sls_ship_dt,sls_due_dt,sls_sales,sls_quantity,sls_price FROM silver.crm_sales_details EXCEPT SELECT CONVERT(varbinary(100),sls_ord_num),CONVERT(varbinary(100),sls_prd_key),sls_cust_id,sls_order_dt,sls_ship_dt,sls_due_dt,sls_sales,sls_quantity,sls_price FROM #expected_sales)
 OR EXISTS(SELECT CONVERT(varbinary(100),sls_ord_num),CONVERT(varbinary(100),sls_prd_key),sls_cust_id,sls_order_dt,sls_ship_dt,sls_due_dt,sls_sales,sls_quantity,sls_price FROM #expected_sales EXCEPT SELECT CONVERT(varbinary(100),sls_ord_num),CONVERT(varbinary(100),sls_prd_key),sls_cust_id,sls_order_dt,sls_ship_dt,sls_due_dt,sls_sales,sls_quantity,sls_price FROM silver.crm_sales_details)
 OR EXISTS(SELECT sls_ord_num,sls_prd_key FROM silver.crm_sales_details GROUP BY sls_ord_num,sls_prd_key HAVING COUNT(*)>1)
 OR EXISTS(SELECT 1 FROM silver.crm_sales_details WHERE dwh_create_date IS NULL)
  THROW 50907,'Sales differs from expected source transformation. Existing rows preserved; approval required before replacement.',1;
 COMMIT TRANSACTION;
 SELECT 'PASS: sales source/target rows',@source,(SELECT COUNT_BIG(*) FROM silver.crm_sales_details);
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
