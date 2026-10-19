-- Appended to read-only transaction by preview_views.py; temp tables only.
SELECT 'customers',COUNT_BIG(*),COUNT(DISTINCT customer_key),COUNT(DISTINCT customer_id),COUNT(DISTINCT customer_number) FROM #customers;
SELECT 'products',COUNT_BIG(*),COUNT(DISTINCT product_key),COUNT(DISTINCT product_id),COUNT(DISTINCT product_number) FROM #products;
SELECT 'sales',COUNT_BIG(*),SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END),SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END),SUM(CONVERT(bigint,sales_amount)),SUM(CONVERT(bigint,quantity)) FROM #sales;
SELECT 'customer_reference_differences', (SELECT COUNT(*) FROM(SELECT * FROM #customers EXCEPT SELECT * FROM #course_customers)x), (SELECT COUNT(*) FROM(SELECT * FROM #course_customers EXCEPT SELECT * FROM #customers)x);
SELECT 'category_warning',category_id,COUNT(*) FROM #products WHERE category IS NULL GROUP BY category_id;
SELECT 'customer_unknowns',SUM(CASE WHEN gender='n/a' THEN 1 ELSE 0 END),SUM(CASE WHEN birthdate IS NULL THEN 1 ELSE 0 END),SUM(CASE WHEN country='n/a' THEN 1 ELSE 0 END) FROM #customers;
SELECT 'gender_audit',SUM(CASE WHEN ci.cst_gndr IN('Male','Female') AND ca.gen IN('Male','Female') AND ci.cst_gndr<>ca.gen THEN 1 ELSE 0 END),SUM(CASE WHEN LOWER(TRIM(COALESCE(ci.cst_gndr,''))) IN('','n/a') AND ca.gen IN('Male','Female') THEN 1 ELSE 0 END) FROM silver.crm_cust_info ci LEFT JOIN silver.erp_cust_az12 ca ON ca.cid=ci.cst_key;
IF EXISTS(SELECT customer_id FROM #customers GROUP BY customer_id HAVING COUNT(*)<>1 OR customer_id IS NULL)
 OR EXISTS(SELECT customer_number FROM #customers GROUP BY customer_number HAVING COUNT(*)<>1 OR customer_number IS NULL)
 OR EXISTS(SELECT customer_key FROM #customers GROUP BY customer_key HAVING COUNT(*)<>1)
 OR EXISTS(SELECT product_id FROM #products GROUP BY product_id HAVING COUNT(*)<>1 OR product_id IS NULL)
 OR EXISTS(SELECT product_number FROM #products GROUP BY product_number HAVING COUNT(*)<>1 OR product_number IS NULL)
 OR EXISTS(SELECT product_key FROM #products GROUP BY product_key HAVING COUNT(*)<>1)
 OR EXISTS(SELECT id FROM silver.erp_px_cat_g1v2 GROUP BY id HAVING COUNT(*)<>1 OR id IS NULL)
 THROW 51802,'Dimension key validation failed.',1;
IF (SELECT COUNT(*) FROM #customers)<>(SELECT COUNT(*) FROM silver.crm_cust_info)
 OR (SELECT COUNT(*) FROM #products)<>(SELECT COUNT(*) FROM silver.crm_prd_info WHERE prd_end_dt IS NULL)
 OR (SELECT COUNT(*) FROM #sales)<>(SELECT COUNT(*) FROM silver.crm_sales_details)
 OR EXISTS(SELECT cst_id FROM silver.crm_cust_info EXCEPT SELECT customer_id FROM #customers)
 OR EXISTS(SELECT prd_key FROM silver.crm_prd_info WHERE prd_end_dt IS NULL EXCEPT SELECT product_number FROM #products)
 OR EXISTS(SELECT 1 FROM #sales WHERE customer_key IS NULL OR product_key IS NULL)
 OR EXISTS(SELECT order_number,product_key FROM #sales GROUP BY order_number,product_key HAVING COUNT(*)<>1)
 THROW 51803,'Coverage, unmatched references or fact grain failed.',1;
-- Recover natural keys to compare every projected fact value with Silver.
IF EXISTS(SELECT s.order_number,p.product_number,c.customer_id,s.order_date,s.shipping_date,s.due_date,s.sales_amount,s.quantity,s.price FROM #sales s JOIN #products p ON p.product_key=s.product_key JOIN #customers c ON c.customer_key=s.customer_key
 EXCEPT SELECT sls_ord_num,sls_prd_key,sls_cust_id,sls_order_dt,sls_ship_dt,sls_due_dt,sls_sales,sls_quantity,sls_price FROM silver.crm_sales_details)
 OR EXISTS(SELECT sls_ord_num,sls_prd_key,sls_cust_id,sls_order_dt,sls_ship_dt,sls_due_dt,sls_sales,sls_quantity,sls_price FROM silver.crm_sales_details
 EXCEPT SELECT s.order_number,p.product_number,c.customer_id,s.order_date,s.shipping_date,s.due_date,s.sales_amount,s.quantity,s.price FROM #sales s JOIN #products p ON p.product_key=s.product_key JOIN #customers c ON c.customer_key=s.customer_key)
 THROW 51804,'Full fact reconciliation failed.',1;
COMMIT TRANSACTION;
PRINT 'PASS: exact three SELECT bodies, key uniqueness, coverage and full fact reconciliation. No Gold DDL executed.';
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
