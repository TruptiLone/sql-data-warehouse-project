-- Read-only checks; run against local DataWarehouse with sqlcmd -b.
:ON ERROR EXIT
SET NOCOUNT ON;
IF DB_NAME() <> N'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition')) <> 3
    THROW 50400, 'Expected local DataWarehouse.', 1;
SELECT COUNT_BIG(*) AS sales_null_order_ids FROM bronze.crm_sales_details WHERE sls_ord_num IS NULL;
SELECT COUNT_BIG(*) AS sales_null_product_keys FROM bronze.crm_sales_details WHERE sls_prd_key IS NULL;
SELECT COUNT_BIG(*) AS sales_null_customer_ids FROM bronze.crm_sales_details WHERE sls_cust_id IS NULL;
-- Orders can contain multiple products; order number alone is not a unique line key.
SELECT COUNT_BIG(*) AS repeated_order_product_groups
FROM (
 SELECT sls_ord_num, sls_prd_key FROM bronze.crm_sales_details
 GROUP BY sls_ord_num, sls_prd_key HAVING COUNT_BIG(*) > 1
) AS duplicates;
