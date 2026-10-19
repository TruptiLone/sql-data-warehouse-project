:ON ERROR EXIT
IF DB_NAME() <> 'DataWarehouse' OR CONVERT(int, SERVERPROPERTY('EngineEdition')) <> 3
    THROW 51200, 'Expected local DataWarehouse.', 1;
SET NOCOUNT ON;
SELECT name FROM sys.tables
WHERE schema_id = SCHEMA_ID('silver');
SELECT
    'customers',
    COUNT(*),
    COUNT(DISTINCT cid),
    SUM(CASE WHEN cid LIKE 'NAS%' THEN 1 ELSE 0 END),
    SUM(CASE WHEN bdate > CONVERT(date, GETDATE()) THEN 1 ELSE 0 END),
    SUM(CASE WHEN bdate < DATEADD(YEAR, -100, CONVERT(date, GETDATE())) THEN 1 ELSE 0 END),
    MIN(bdate),
    MAX(bdate)
FROM bronze.erp_cust_az12;
SELECT
    'gender',
    gen,
    COUNT(*)
FROM bronze.erp_cust_az12
GROUP BY gen;
SELECT
    'country',
    cntry,
    COUNT(*)
FROM bronze.erp_loc_a101
GROUP BY cntry;
SELECT
    'category',
    cat,
    COUNT(*)
FROM bronze.erp_px_cat_g1v2
GROUP BY cat;
SELECT
    'subcategory',
    subcat,
    COUNT(*)
FROM bronze.erp_px_cat_g1v2
GROUP BY subcat;
SELECT
    'maintenance',
    maintenance,
    COUNT(*)
FROM bronze.erp_px_cat_g1v2
GROUP BY maintenance;
SELECT
    'category quality',
    COUNT(*),
    COUNT(DISTINCT id),
    SUM(
        CASE
            WHEN id IS NULL OR cat IS NULL OR subcat IS NULL OR maintenance IS NULL THEN 1 ELSE 0
        END
    ),
    SUM(
        CASE
            WHEN
                DATALENGTH(id) <> DATALENGTH(TRIM(id))
                OR DATALENGTH(cat) <> DATALENGTH(TRIM(cat))
                OR DATALENGTH(subcat) <> DATALENGTH(TRIM(subcat))
                OR DATALENGTH(maintenance) <> DATALENGTH(TRIM(maintenance))
                THEN 1
            ELSE 0
        END
    )
FROM bronze.erp_px_cat_g1v2;
SELECT
    'customer unmatched',
    COUNT(*)
FROM bronze.erp_cust_az12 e
WHERE NOT EXISTS (
    SELECT 1 FROM silver.crm_cust_info c
    WHERE
        c.cst_key
        = CASE
            WHEN LEFT(TRIM(e.cid), 3) = 'NAS' THEN SUBSTRING(TRIM(e.cid), 4, 50) ELSE TRIM(e.cid)
        END
);
SELECT
    'location unmatched',
    COUNT(*)
FROM bronze.erp_loc_a101 e
WHERE NOT EXISTS (
    SELECT 1 FROM silver.crm_cust_info c
    WHERE c.cst_key = REPLACE(TRIM(e.cid), '-', '')
);
SELECT
    'ERP categories unused by CRM',
    e.id,
    e.cat,
    e.subcat
FROM bronze.erp_px_cat_g1v2 e
WHERE NOT EXISTS (
    SELECT 1 FROM silver.crm_prd_info p
    WHERE p.cat_id = e.id
);
SELECT
    'CRM categories absent from ERP',
    p.cat_id,
    COUNT(*)
FROM silver.crm_prd_info p
WHERE
    NOT EXISTS (
        SELECT 1 FROM bronze.erp_px_cat_g1v2 e
        WHERE e.id = p.cat_id
    )
GROUP BY p.cat_id;

SELECT
    'as_of',
    CONVERT(date, GETDATE());
SELECT
    'location IDs',
    COUNT(*),
    COUNT(DISTINCT cid),
    SUM(CASE WHEN cid LIKE '%-%' THEN 1 ELSE 0 END)
FROM bronze.erp_loc_a101;
SELECT
    'customer whitespace',
    SUM(CASE WHEN DATALENGTH(cid) <> DATALENGTH(TRIM(cid)) THEN 1 ELSE 0 END),
    SUM(CASE WHEN DATALENGTH(gen) <> DATALENGTH(TRIM(gen)) THEN 1 ELSE 0 END)
FROM bronze.erp_cust_az12;
SELECT
    'country whitespace',
    SUM(CASE WHEN DATALENGTH(cntry) <> DATALENGTH(TRIM(cntry)) THEN 1 ELSE 0 END)
FROM bronze.erp_loc_a101;
SELECT
    'conflicting subcategories',
    COUNT(*)
FROM (
    SELECT subcat FROM bronze.erp_px_cat_g1v2
    GROUP BY subcat
    HAVING COUNT(DISTINCT cat) > 1
) q;
