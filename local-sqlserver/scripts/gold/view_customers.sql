-- Prepared DDL only; not executed. Use a verified local Docker connection.
:ON ERROR EXIT
USE [DataWarehouse];
GO
IF
    DB_NAME() <> 'DataWarehouse' OR CONVERT(int, SERVERPROPERTY('EngineEdition')) <> 3
    OR CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
    OR ISNULL(CONVERT(varchar(48), CONNECTIONPROPERTY('local_net_address')), '') <> '127.0.0.1'
    THROW 51700, 'Expected verified local Developer DataWarehouse over loopback.', 1;
IF OBJECT_ID('gold.dim_customers') IS NOT NULL AND OBJECT_ID('gold.dim_customers', 'V') IS NULL
    THROW 51701, 'Gold customer name conflict; stop for approval. Do not replace a table.', 1;
GO
CREATE OR ALTER VIEW gold.dim_customers AS
-- BEGIN CUSTOMER SELECT
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,
    ci.cst_id AS customer_id,
    ci.cst_key AS customer_number,
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,
    la.cntry AS country,
    ci.cst_marital_status AS marital_status,
    CAST(CASE
        WHEN LOWER(TRIM(ci.cst_gndr)) = 'male' THEN 'Male'
        WHEN LOWER(TRIM(ci.cst_gndr)) = 'female' THEN 'Female'
        WHEN LOWER(TRIM(ca.gen)) = 'male' THEN 'Male'
        WHEN LOWER(TRIM(ca.gen)) = 'female' THEN 'Female'
        ELSE 'n/a'
    END AS nvarchar(50)) AS gender,
    ca.bdate AS birthdate,
    ci.cst_create_date AS create_date
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 AS la ON ci.cst_key = la.cid
-- END CUSTOMER SELECT
;
GO
