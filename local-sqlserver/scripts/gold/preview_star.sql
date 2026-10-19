-- Read-only provisional star preview; instructor ddl_gold.sql still required.
:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 OR ISNULL(CONVERT(varchar(48),CONNECTIONPROPERTY('local_net_address')),'')<>'127.0.0.1'
 THROW 51800,'Expected verified local DataWarehouse over loopback.',1;
SELECT 'existing_gold_objects' AS report,name,type_desc FROM sys.objects
WHERE schema_id=SCHEMA_ID('gold') AND name IN('dim_customers','dim_products','fact_sales');
IF EXISTS(SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID('gold')
 AND name IN('dim_customers','dim_products','fact_sales') AND type<>'V')
 THROW 51801,'Non-view Gold naming conflict; stop for review.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @n bigint;
 SELECT @n=COUNT_BIG(*) FROM silver.crm_cust_info WITH(TABLOCK,HOLDLOCK);
 SELECT @n=COUNT_BIG(*) FROM silver.crm_prd_info WITH(TABLOCK,HOLDLOCK);
 SELECT @n=COUNT_BIG(*) FROM silver.crm_sales_details WITH(TABLOCK,HOLDLOCK);
 SELECT @n=COUNT_BIG(*) FROM silver.erp_cust_az12 WITH(TABLOCK,HOLDLOCK);
 SELECT @n=COUNT_BIG(*) FROM silver.erp_loc_a101 WITH(TABLOCK,HOLDLOCK);
 SELECT @n=COUNT_BIG(*) FROM silver.erp_px_cat_g1v2 WITH(TABLOCK,HOLDLOCK);
 SELECT ROW_NUMBER() OVER(ORDER BY ci.cst_id) customer_key,ci.cst_id customer_id,ci.cst_key customer_number
 INTO #customers FROM silver.crm_cust_info ci
 LEFT JOIN silver.erp_cust_az12 ca ON ca.cid=ci.cst_key
 LEFT JOIN silver.erp_loc_a101 la ON la.cid=ci.cst_key;
 SELECT ROW_NUMBER() OVER(ORDER BY pi.prd_start_dt,pi.prd_key) product_key,
 pi.prd_id product_id,pi.prd_key product_number,pi.cat_id category_id,pc.id matched_category_id
 INTO #products FROM silver.crm_prd_info pi
 LEFT JOIN silver.erp_px_cat_g1v2 pc ON pc.id=pi.cat_id
 WHERE pi.prd_end_dt IS NULL;
 SELECT sd.sls_ord_num order_number,pr.product_key,cu.customer_key,
 sd.sls_prd_key source_product_number,sd.sls_sales sales_amount,sd.sls_quantity quantity
 INTO #sales FROM silver.crm_sales_details sd
 LEFT JOIN #products pr ON sd.sls_prd_key=pr.product_number
 LEFT JOIN #customers cu ON sd.sls_cust_id=cu.customer_id;
 SELECT 'customers' report,COUNT_BIG(*) rows,COUNT(DISTINCT customer_key) unique_keys,
 COUNT(DISTINCT customer_id) unique_ids,COUNT(DISTINCT customer_number) unique_numbers FROM #customers;
 SELECT 'products' report,COUNT_BIG(*) rows,COUNT(DISTINCT product_key) unique_keys,
 COUNT(DISTINCT product_id) unique_ids,COUNT(DISTINCT product_number) unique_numbers FROM #products;
 SELECT 'sales' report,COUNT_BIG(*) rows,
 SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) unmatched_products,
 SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) unmatched_customers,
 SUM(CONVERT(bigint,sales_amount)) sales_amount,SUM(CONVERT(bigint,quantity)) quantity FROM #sales;
 SELECT 'category_warning' report,category_id,COUNT(*) products FROM #products
 WHERE matched_category_id IS NULL GROUP BY category_id;
 SELECT 'unused_category' report,id,cat,subcat,maintenance FROM silver.erp_px_cat_g1v2 pc
 WHERE NOT EXISTS(SELECT 1 FROM silver.crm_prd_info pi WHERE pi.cat_id=pc.id);
 IF (SELECT COUNT(*) FROM #customers)<>(SELECT COUNT(*) FROM silver.crm_cust_info)
 OR EXISTS(SELECT customer_id FROM #customers GROUP BY customer_id HAVING COUNT(*)<>1)
 OR EXISTS(SELECT customer_number FROM #customers GROUP BY customer_number HAVING COUNT(*)<>1)
 OR EXISTS(SELECT product_number FROM #products GROUP BY product_number HAVING COUNT(*)<>1)
 OR EXISTS(SELECT product_id FROM #products GROUP BY product_id HAVING COUNT(*)<>1)
 OR (SELECT COUNT(*) FROM #sales)<>(SELECT COUNT(*) FROM silver.crm_sales_details)
 OR EXISTS(SELECT order_number,source_product_number FROM #sales GROUP BY order_number,source_product_number HAVING COUNT(*)<>1)
 OR EXISTS(SELECT 1 FROM #sales WHERE customer_key IS NULL OR product_key IS NULL)
 THROW 51802,'Star grain/key/reference validation failed.',1;
 COMMIT TRANSACTION;
 PRINT 'PASS: provisional star preview only; no Gold DDL executed.';
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
