:ON ERROR EXIT
SET NOCOUNT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 OR CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
 THROW 50800,'Expected local Developer DataWarehouse.',1;
SELECT 'existing_silver_sales',COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID('silver') AND name='crm_sales_details';
SELECT 'source_rows',COUNT_BIG(*) FROM bronze.crm_sales_details;
SELECT 'nulls',SUM(CASE WHEN sls_ord_num IS NULL THEN 1 ELSE 0 END) AS order_ids,
 SUM(CASE WHEN sls_prd_key IS NULL THEN 1 ELSE 0 END) AS product_keys,
 SUM(CASE WHEN sls_cust_id IS NULL THEN 1 ELSE 0 END) AS customer_ids,
 SUM(CASE WHEN sls_quantity IS NULL THEN 1 ELSE 0 END) AS quantities,
 SUM(CASE WHEN sls_sales IS NULL THEN 1 ELSE 0 END) AS sales,
 SUM(CASE WHEN sls_price IS NULL THEN 1 ELSE 0 END) AS prices
FROM bronze.crm_sales_details;
SELECT 'date_profile',v.field,COUNT_BIG(*) AS rows,
 SUM(CASE WHEN v.raw_date IS NULL THEN 1 ELSE 0 END) AS null_dates,
 SUM(CASE WHEN v.raw_date=0 THEN 1 ELSE 0 END) AS zeros,
 SUM(CASE WHEN LEN(CONVERT(varchar(11),v.raw_date))<>8 AND v.raw_date<>0 THEN 1 ELSE 0 END) AS non_eight_digit,
 SUM(CASE WHEN LEN(CONVERT(varchar(11),v.raw_date))=8 AND TRY_CONVERT(date,CONVERT(varchar(11),v.raw_date),112) IS NULL THEN 1 ELSE 0 END) AS invalid_eight_digit,
 MIN(CASE WHEN LEN(CONVERT(varchar(11),v.raw_date))=8 THEN TRY_CONVERT(date,CONVERT(varchar(11),v.raw_date),112) END) AS min_valid,
 MAX(CASE WHEN LEN(CONVERT(varchar(11),v.raw_date))=8 THEN TRY_CONVERT(date,CONVERT(varchar(11),v.raw_date),112) END) AS max_valid
FROM bronze.crm_sales_details CROSS APPLY(VALUES('order',sls_order_dt),('ship',sls_ship_dt),('due',sls_due_dt)) v(field,raw_date)
GROUP BY v.field;
SELECT 'invalid_date_value',v.field,v.raw_date,COUNT(*) FROM bronze.crm_sales_details
CROSS APPLY(VALUES('order',sls_order_dt),('ship',sls_ship_dt),('due',sls_due_dt)) v(field,raw_date)
WHERE v.raw_date IS NULL OR LEN(CONVERT(varchar(11),v.raw_date))<>8 OR TRY_CONVERT(date,CONVERT(varchar(11),v.raw_date),112) IS NULL
GROUP BY v.field,v.raw_date;
SELECT 'amount_profile',
 SUM(CASE WHEN sls_quantity<=0 THEN 1 ELSE 0 END) AS nonpositive_quantity,
 SUM(CASE WHEN sls_price=0 THEN 1 ELSE 0 END) AS zero_price,
 SUM(CASE WHEN sls_price<0 THEN 1 ELSE 0 END) AS negative_price,
 SUM(CASE WHEN sls_sales=0 THEN 1 ELSE 0 END) AS zero_sales,
 SUM(CASE WHEN sls_sales<0 THEN 1 ELSE 0 END) AS negative_sales,
 SUM(CASE WHEN CONVERT(bigint,sls_sales)<>CONVERT(bigint,sls_quantity)*sls_price THEN 1 ELSE 0 END) AS unequal_amounts,
 SUM(CASE WHEN sls_sales IS NULL OR sls_price IS NULL OR sls_quantity IS NULL OR CONVERT(bigint,sls_sales)<>CONVERT(bigint,sls_quantity)*sls_price THEN 1 ELSE 0 END) AS missing_or_unequal
FROM bronze.crm_sales_details;
SELECT 'amount_anomaly_pattern',sls_sales,sls_quantity,sls_price,COUNT(*) AS rows
FROM bronze.crm_sales_details WHERE sls_sales IS NULL OR sls_price IS NULL OR sls_quantity IS NULL
 OR sls_sales<=0 OR sls_price<=0 OR sls_quantity<=0 OR CONVERT(bigint,sls_sales)<>CONVERT(bigint,sls_quantity)*sls_price
GROUP BY sls_sales,sls_quantity,sls_price ORDER BY sls_sales,sls_quantity,sls_price;
SELECT 'duplicate_order_product_groups',COUNT(*) FROM (
 SELECT sls_ord_num,sls_prd_key FROM bronze.crm_sales_details GROUP BY sls_ord_num,sls_prd_key HAVING COUNT(*)>1) q;
SELECT 'missing_customer_references',COUNT(*) FROM bronze.crm_sales_details s
WHERE NOT EXISTS(SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_id=s.sls_cust_id);
SELECT 'missing_product_key_references',COUNT(*) FROM bronze.crm_sales_details s
WHERE NOT EXISTS(SELECT 1 FROM silver.crm_prd_info p WHERE p.prd_key=TRIM(s.sls_prd_key));
;WITH d AS (
 SELECT *,CASE WHEN LEN(CONVERT(varchar(11),sls_order_dt))=8 THEN TRY_CONVERT(date,CONVERT(varchar(11),sls_order_dt),112) END AS od,
 TRY_CONVERT(date,CONVERT(varchar(11),sls_ship_dt),112) AS sd,
 TRY_CONVERT(date,CONVERT(varchar(11),sls_due_dt),112) AS dd
 FROM bronze.crm_sales_details
)
SELECT 'chronology',SUM(CASE WHEN od>sd THEN 1 ELSE 0 END) AS order_after_ship,
 SUM(CASE WHEN od>dd THEN 1 ELSE 0 END) AS order_after_due,
 SUM(CASE WHEN sd>dd THEN 1 ELSE 0 END) AS ship_after_due,
 SUM(CASE WHEN od>CONVERT(date,GETDATE()) OR sd>CONVERT(date,GETDATE()) OR dd>CONVERT(date,GETDATE()) THEN 1 ELSE 0 END) AS future_rows,
 SUM(CASE WHEN od IS NOT NULL AND no_history_match=1 THEN 1 ELSE 0 END) AS no_history_match
FROM d OUTER APPLY (SELECT CASE WHEN EXISTS(SELECT 1 FROM silver.crm_prd_info p WHERE p.prd_key=TRIM(d.sls_prd_key) AND d.od>=p.prd_start_dt AND (d.od<=p.prd_end_dt OR p.prd_end_dt IS NULL)) THEN 0 ELSE 1 END AS no_history_match) h;
SELECT 'trim_changes',SUM(CASE WHEN DATALENGTH(sls_ord_num)<>DATALENGTH(TRIM(sls_ord_num)) THEN 1 ELSE 0 END),
 SUM(CASE WHEN DATALENGTH(sls_prd_key)<>DATALENGTH(TRIM(sls_prd_key)) THEN 1 ELSE 0 END) FROM bronze.crm_sales_details;

SET NOCOUNT ON;
SELECT 'product_range',MIN(prd_start_dt),MAX(prd_start_dt) FROM silver.crm_prd_info;
;WITH d AS (
 SELECT *,CASE WHEN LEN(CONVERT(varchar(11),sls_order_dt))=8 THEN TRY_CONVERT(date,CONVERT(varchar(11),sls_order_dt),112) END AS od FROM bronze.crm_sales_details
), refs AS (
 SELECT d.*,h.matches,h.first_start FROM d OUTER APPLY (
 SELECT (SELECT COUNT(*) FROM silver.crm_prd_info p WHERE p.prd_key=d.sls_prd_key AND d.od>=p.prd_start_dt AND (d.od<=p.prd_end_dt OR p.prd_end_dt IS NULL)) AS matches, (SELECT MIN(p.prd_start_dt) FROM silver.crm_prd_info p WHERE p.prd_key=d.sls_prd_key) AS first_start
 ) h
)
SELECT 'history',SUM(CASE WHEN od IS NULL THEN 1 ELSE 0 END) AS unknown_date,
 SUM(CASE WHEN od IS NOT NULL AND matches=1 THEN 1 ELSE 0 END) AS exact_match,
 SUM(CASE WHEN od<first_start THEN 1 ELSE 0 END) AS before_first_version,
 SUM(CASE WHEN od IS NOT NULL AND matches=0 AND od>=first_start THEN 1 ELSE 0 END) AS other_gap,
 SUM(CASE WHEN matches>1 THEN 1 ELSE 0 END) AS ambiguous FROM refs;
SELECT 'repair_counts',
 SUM(CASE WHEN sls_price>0 AND (sls_sales IS NULL OR CONVERT(bigint,sls_sales)<>CONVERT(bigint,sls_price)*sls_quantity) THEN 1 ELSE 0 END) AS sales_rebuilt,
 SUM(CASE WHEN (sls_price IS NULL OR sls_price<=0) AND sls_sales>0 AND sls_sales%sls_quantity=0 THEN 1 ELSE 0 END) AS price_derived,
 SUM(CASE WHEN (sls_price IS NULL OR sls_price<=0) AND (sls_sales IS NULL OR sls_sales<=0 OR sls_sales%sls_quantity<>0) THEN 1 ELSE 0 END) AS unresolved
FROM bronze.crm_sales_details;
SELECT 'negative_context',s.sls_sales,s.sls_quantity,s.sls_price,
 (SELECT COUNT(*) FROM bronze.crm_sales_details p WHERE p.sls_prd_key=s.sls_prd_key AND p.sls_price=CASE WHEN s.sls_price>0 THEN s.sls_price ELSE s.sls_sales/NULLIF(s.sls_quantity,0) END AND p.sls_sales=CONVERT(bigint,p.sls_quantity)*p.sls_price) AS consistent_same_product_price_peers
FROM bronze.crm_sales_details s WHERE s.sls_sales<0 OR s.sls_price<0;
SELECT 'key_blanks',COUNT(*) FROM bronze.crm_sales_details WHERE NULLIF(TRIM(sls_ord_num),'') IS NULL OR NULLIF(TRIM(sls_prd_key),'') IS NULL;
