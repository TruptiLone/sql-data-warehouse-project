-- Analysis only. Run through the verified local Docker connection; no DDL/DML.
:ON ERROR EXIT
SET NOCOUNT ON;
IF
    DB_NAME() <> 'DataWarehouse' OR CONVERT(int, SERVERPROPERTY('EngineEdition')) <> 3
    OR CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
    OR ISNULL(CONVERT(varchar(48), CONNECTIONPROPERTY('local_net_address')), '') <> '127.0.0.1'
    THROW 51500, 'Expected verified local Developer DataWarehouse over loopback.', 1;
SELECT
    'snapshot',
    SYSDATETIME(),
    DB_NAME();
SELECT
    t.name,
    c.column_id,
    c.name,
    TYPE_NAME(c.user_type_id),
    c.max_length,
    c.is_nullable
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
WHERE t.schema_id = SCHEMA_ID('silver')
ORDER BY t.name, c.column_id;
SELECT
    'constraints',
    t.name,
    i.name,
    i.is_primary_key,
    i.is_unique
FROM sys.tables t
JOIN sys.indexes i ON i.object_id = t.object_id
WHERE t.schema_id = SCHEMA_ID('silver') AND i.is_unique = 1;
SELECT
    'foreign_keys',
    name
FROM sys.foreign_keys
WHERE parent_object_id IN (
    SELECT object_id FROM sys.tables
    WHERE schema_id = SCHEMA_ID('silver')
);
SELECT
    'crm_cust_info',
    COUNT_BIG(*),
    COUNT(DISTINCT cst_id),
    COUNT(DISTINCT cst_key),
    SUM(CASE WHEN cst_id IS NULL OR cst_key IS NULL THEN 1 ELSE 0 END)
FROM silver.crm_cust_info;
SELECT
    'crm_prd_info',
    COUNT_BIG(*),
    COUNT(DISTINCT prd_id),
    COUNT(DISTINCT prd_key),
    SUM(CASE WHEN prd_id IS NULL OR prd_key IS NULL THEN 1 ELSE 0 END)
FROM silver.crm_prd_info;
SELECT
    'crm_sales_details',
    COUNT_BIG(*),
    COUNT(DISTINCT sls_ord_num),
    SUM(CONVERT(bigint, sls_sales)),
    SUM(CONVERT(bigint, sls_quantity))
FROM silver.crm_sales_details;
SELECT
    'erp_cust_az12',
    COUNT_BIG(*),
    COUNT(DISTINCT cid),
    SUM(CASE WHEN cid IS NULL THEN 1 ELSE 0 END)
FROM silver.erp_cust_az12;
SELECT
    'erp_loc_a101',
    COUNT_BIG(*),
    COUNT(DISTINCT cid),
    SUM(CASE WHEN cid IS NULL THEN 1 ELSE 0 END)
FROM silver.erp_loc_a101;
SELECT
    'erp_px_cat_g1v2',
    COUNT_BIG(*),
    COUNT(DISTINCT id),
    SUM(CASE WHEN id IS NULL THEN 1 ELSE 0 END)
FROM silver.erp_px_cat_g1v2;
SELECT
    'customer_integration',
    COUNT_BIG(*),
    SUM(CASE WHEN e.cid IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN l.cid IS NULL THEN 1 ELSE 0 END),
    SUM(
        CASE
            WHEN
                c.cst_gndr IN ('Male', 'Female')
                AND e.gen IN ('Male', 'Female')
                AND c.cst_gndr <> e.gen
                THEN 1
            ELSE 0
        END
    ),
    SUM(CASE WHEN c.cst_gndr = 'n/a' AND e.gen IN ('Male', 'Female') THEN 1 ELSE 0 END)
FROM silver.crm_cust_info c
LEFT JOIN silver.erp_cust_az12 e ON e.cid = c.cst_key
LEFT JOIN silver.erp_loc_a101 l ON l.cid = c.cst_key;
SELECT
    'erp_orphans',
    (
        SELECT COUNT(*) FROM silver.erp_cust_az12 e
        WHERE NOT EXISTS (
            SELECT 1 FROM silver.crm_cust_info c
            WHERE c.cst_key = e.cid
        )
    ),
    (
        SELECT COUNT(*) FROM silver.erp_loc_a101 e
        WHERE NOT EXISTS (
            SELECT 1 FROM silver.crm_cust_info c
            WHERE c.cst_key = e.cid
        )
    );
SELECT
    'gender',
    cst_gndr,
    COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_gndr;
SELECT
    'country',
    cntry,
    COUNT(*)
FROM silver.erp_loc_a101
GROUP BY cntry;
SELECT
    'birthdates',
    MIN(bdate),
    MAX(bdate),
    SUM(CASE WHEN bdate IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN bdate < DATEADD(YEAR, -100, CAST(GETDATE() AS date)) THEN 1 ELSE 0 END)
FROM silver.erp_cust_az12;
SELECT
    'category_gap',
    p.cat_id,
    COUNT(*),
    COUNT(DISTINCT p.prd_key),
    SUM(CASE WHEN p.prd_end_dt IS NULL THEN 1 ELSE 0 END)
FROM silver.crm_prd_info p
LEFT JOIN silver.erp_px_cat_g1v2 c ON c.id = p.cat_id
WHERE c.id IS NULL
GROUP BY p.cat_id;
SELECT
    'unused_category',
    c.id,
    c.cat,
    c.subcat,
    c.maintenance
FROM silver.erp_px_cat_g1v2 c
WHERE NOT EXISTS (
    SELECT 1 FROM silver.crm_prd_info p
    WHERE p.cat_id = c.id
);
SELECT
    'pedal_products',
    prd_id,
    prd_key,
    prd_nm,
    cat_id,
    prd_start_dt,
    prd_end_dt
FROM silver.crm_prd_info
WHERE cat_id IN ('CO_PE', 'CO_PD')
ORDER BY prd_key, prd_start_dt;
SELECT
    'line',
    prd_line,
    COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_line;
SELECT
    'history',
    SUM(CASE WHEN prd_end_dt IS NULL THEN 1 ELSE 0 END),
    MIN(prd_start_dt),
    MAX(prd_start_dt),
    SUM(CASE WHEN prd_start_dt IS NULL OR prd_end_dt < prd_start_dt THEN 1 ELSE 0 END)
FROM silver.crm_prd_info;
SELECT
    'version_distribution',
    versions,
    COUNT(*)
FROM (SELECT
    prd_key,
    COUNT(*) versions
FROM silver.crm_prd_info
GROUP BY prd_key) x
GROUP BY versions
;
SELECT
    'current_key_failures',
    COUNT(*)
FROM (
    SELECT prd_key FROM silver.crm_prd_info
    GROUP BY prd_key
    HAVING SUM(CASE WHEN prd_end_dt IS NULL THEN 1 ELSE 0 END) <> 1
) x;
SELECT
    'sales_duplicate_keys',
    COUNT(*)
FROM (SELECT
    sls_ord_num,
    sls_prd_key
FROM silver.crm_sales_details
GROUP BY sls_ord_num, sls_prd_key
HAVING COUNT(*) > 1) x;
SELECT
    'sales_null_keys',
    COUNT(*)
FROM silver.crm_sales_details
WHERE sls_ord_num IS NULL OR sls_prd_key IS NULL OR sls_cust_id IS NULL;
SELECT
    'sales_references',
    SUM(CASE WHEN c.cst_id IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN p.prd_key IS NULL THEN 1 ELSE 0 END),
    COUNT_BIG(*)
FROM silver.crm_sales_details s
LEFT JOIN silver.crm_cust_info c ON c.cst_id = s.sls_cust_id
LEFT JOIN silver.crm_prd_info p ON p.prd_key = s.sls_prd_key AND p.prd_end_dt IS NULL;
SELECT
    'naive_history_join',
    COUNT_BIG(*)
FROM silver.crm_sales_details s
JOIN silver.crm_prd_info p ON p.prd_key = s.sls_prd_key;
SELECT
    'temporal_matches',
    matches,
    COUNT_BIG(*)
FROM silver.crm_sales_details s
CROSS APPLY (
    SELECT COUNT(*) matches FROM silver.crm_prd_info p
    WHERE
        p.prd_key = s.sls_prd_key
        AND s.sls_order_dt >= p.prd_start_dt
        AND (s.sls_order_dt <= p.prd_end_dt OR p.prd_end_dt IS NULL)
) m
GROUP BY matches
;
SELECT
    'temporal_status',
    CASE
        WHEN s.sls_order_dt IS NULL THEN 'UNKNOWN_DATE' WHEN
            s.sls_order_dt < p.first_start
            THEN 'BEFORE_HISTORY'
        ELSE 'WITHIN_HISTORY'
    END,
    COUNT_BIG(*)
FROM silver.crm_sales_details s
JOIN (SELECT
    prd_key,
    MIN(prd_start_dt) first_start
FROM silver.crm_prd_info
GROUP BY prd_key) p ON p.prd_key = s.sls_prd_key
GROUP BY
    CASE WHEN s.sls_order_dt IS NULL THEN 'UNKNOWN_DATE' WHEN s.sls_order_dt < p.first_start THEN 'BEFORE_HISTORY' ELSE 'WITHIN_HISTORY' END;
SELECT
    'sales_by_year',
    YEAR(sls_order_dt),
    COUNT_BIG(*),
    SUM(CONVERT(bigint, sls_sales))
FROM silver.crm_sales_details
GROUP BY YEAR(sls_order_dt)
ORDER BY YEAR(sls_order_dt);
SELECT
    'category_affected_sales',
    COUNT_BIG(*),
    SUM(CONVERT(bigint, sls_sales))
FROM silver.crm_sales_details s
JOIN silver.crm_prd_info p ON p.prd_key = s.sls_prd_key AND p.prd_end_dt IS NULL
WHERE p.cat_id = 'CO_PE';
SELECT
    'gold_objects',
    name,
    type_desc
FROM sys.objects
WHERE schema_id = SCHEMA_ID('gold');
