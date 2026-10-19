-- Prepared DDL only; not executed. Use a verified local Docker connection.
:ON ERROR EXIT
USE [DataWarehouse];
GO
IF
    DB_NAME() <> 'DataWarehouse' OR CONVERT(int, SERVERPROPERTY('EngineEdition')) <> 3
    OR CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
    OR ISNULL(CONVERT(varchar(48), CONNECTIONPROPERTY('local_net_address')), '') <> '127.0.0.1'
    THROW 51700, 'Expected verified local Developer DataWarehouse over loopback.', 1;
IF OBJECT_ID('gold.dim_products') IS NOT NULL AND OBJECT_ID('gold.dim_products', 'V') IS NULL
    THROW 51701, 'Gold object name conflict; stop for approval. Do not replace a table.', 1;
GO
CREATE OR ALTER VIEW gold.dim_products AS
-- BEGIN PRODUCT SELECT
SELECT
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key, -- Surrogate key
    pn.prd_id AS product_id,
    pn.prd_key AS product_number,
    pn.prd_nm AS product_name,
    pn.cat_id AS category_id,
    pc.cat AS category,
    pc.subcat AS subcategory,
    pc.maintenance AS maintenance,
    pn.prd_cost AS cost,
    pn.prd_line AS product_line,
    pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
    ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL
-- END PRODUCT SELECT
;
GO
