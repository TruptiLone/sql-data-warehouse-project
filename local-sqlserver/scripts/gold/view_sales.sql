-- Prepared DDL only; not executed. Use a verified local Docker connection.
:ON ERROR EXIT
USE [DataWarehouse];
GO
IF
    DB_NAME() <> 'DataWarehouse' OR CONVERT(int, SERVERPROPERTY('EngineEdition')) <> 3
    OR CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
    OR ISNULL(CONVERT(varchar(48), CONNECTIONPROPERTY('local_net_address')), '') <> '127.0.0.1'
    THROW 51700, 'Expected verified local Developer DataWarehouse over loopback.', 1;
IF OBJECT_ID('gold.fact_sales') IS NOT NULL AND OBJECT_ID('gold.fact_sales', 'V') IS NULL
    THROW 51701, 'Gold object name conflict; stop for approval. Do not replace a table.', 1;
GO
CREATE OR ALTER VIEW gold.fact_sales AS
-- BEGIN SALES SELECT
SELECT
    sd.sls_ord_num AS order_number,
    pr.product_key AS product_key,
    cu.customer_key AS customer_key,
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS shipping_date,
    sd.sls_due_dt AS due_date,
    sd.sls_sales AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
    ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
    ON sd.sls_cust_id = cu.customer_id
-- END SALES SELECT
;
GO
