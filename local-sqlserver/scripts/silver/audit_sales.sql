-- Read-only CRM Sales audit. Run only against verified local Docker DataWarehouse.
-- SQLCMD mode, sqlcmd -b. No DDL/DML, temp tables, or data changes.
-- Range is inclusive 1900-01-01 through 2050-12-31.
-- Date categories are exclusive: missing, zero, malformed, invalid calendar,
-- valid outside range, valid inside range. A short token is not parsed as a year.
:ON ERROR EXIT
SET NOCOUNT ON;
IF
    DB_NAME() <> 'DataWarehouse' OR CONVERT(int, SERVERPROPERTY('EngineEdition')) <> 3
    OR CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
    THROW 51100, 'Expected verified local Developer DataWarehouse.', 1;
SELECT
    'counts' AS audit_section,
    (SELECT COUNT_BIG(*) FROM bronze.crm_sales_details) AS bronze_sales,
    (SELECT COUNT_BIG(*) FROM silver.crm_sales_details) AS silver_sales,
    (SELECT COUNT(*) FROM silver.crm_cust_info) AS silver_customers,
    (SELECT COUNT(*) FROM silver.crm_prd_info) AS silver_products
FOR JSON PATH;

; WITH raw_dates AS (
    SELECT
        sls_ord_num,
        sls_prd_key,
        v.field_name,
        v.raw_value
    FROM bronze.crm_sales_details
    CROSS APPLY
        (VALUES ('order', sls_order_dt), ('shipping', sls_ship_dt), ('due', sls_due_dt))
            v(field_name, raw_value)
),

parsed AS (
    SELECT
        *,
        CASE
            WHEN raw_value > 0 AND LEN(CONVERT(varchar(11), raw_value)) = 8
                THEN TRY_CONVERT(date, CONVERT(varchar(11), raw_value), 112)
        END AS parsed_date
    FROM raw_dates
),

classified AS (
    SELECT
        *,
        CASE
            WHEN raw_value IS NULL THEN 'missing' WHEN raw_value = 0 THEN 'zero'
            WHEN raw_value < 0 OR LEN(CONVERT(varchar(11), raw_value)) <> 8 THEN 'malformed'
            WHEN parsed_date IS NULL THEN 'invalid_calendar'
            WHEN parsed_date < '19000101' OR parsed_date > '20501231' THEN 'outside_1900_2050'
            ELSE 'valid_in_range'
        END AS classification
    FROM parsed
)

SELECT
    'date_profile' AS audit_section,
    field_name,
    COUNT(*) AS total,
    SUM(CASE WHEN classification = 'missing' THEN 1 ELSE 0 END) AS missing,
    SUM(CASE WHEN classification = 'zero' THEN 1 ELSE 0 END) AS zeros,
    SUM(CASE WHEN classification = 'malformed' THEN 1 ELSE 0 END) AS malformed,
    SUM(CASE WHEN classification = 'invalid_calendar' THEN 1 ELSE 0 END) AS invalid_calendar,
    SUM(CASE WHEN classification = 'outside_1900_2050' THEN 1 ELSE 0 END) AS outside_1900_2050,
    SUM(CASE WHEN classification = 'valid_in_range' THEN 1 ELSE 0 END) AS valid_in_range,
    MIN(parsed_date) AS minimum_valid,
    MAX(parsed_date) AS maximum_valid
FROM classified
GROUP BY field_name
ORDER BY field_name FOR JSON PATH;

; WITH raw_dates AS (
    SELECT
        sls_ord_num,
        sls_prd_key,
        v.field_name,
        v.raw_value
    FROM bronze.crm_sales_details
    CROSS APPLY
        (VALUES ('order', sls_order_dt), ('shipping', sls_ship_dt), ('due', sls_due_dt))
            v(field_name, raw_value)
),

parsed AS (
    SELECT
        *,
        CASE
            WHEN raw_value > 0 AND LEN(CONVERT(varchar(11), raw_value)) = 8
                THEN TRY_CONVERT(date, CONVERT(varchar(11), raw_value), 112)
        END AS parsed_date
    FROM raw_dates
),

classified AS (
    SELECT
        *,
        CASE
            WHEN raw_value IS NULL THEN 'missing' WHEN raw_value = 0 THEN 'zero'
            WHEN raw_value < 0 OR LEN(CONVERT(varchar(11), raw_value)) <> 8 THEN 'malformed'
            WHEN parsed_date IS NULL THEN 'invalid_calendar'
            WHEN parsed_date < '19000101' OR parsed_date > '20501231' THEN 'outside_1900_2050'
            ELSE 'valid_in_range'
        END AS classification
    FROM parsed
)

SELECT
    'date_anomaly_values' AS audit_section,
    field_name,
    raw_value,
    classification,
    COUNT(*) AS rows
FROM classified
WHERE classification <> 'valid_in_range'
GROUP BY field_name, raw_value, classification
ORDER BY field_name, raw_value FOR JSON PATH,
INCLUDE_NULL_VALUES;

; WITH raw_dates AS (
    SELECT
        sls_ord_num,
        sls_prd_key,
        v.field_name,
        v.raw_value
    FROM bronze.crm_sales_details
    CROSS APPLY
        (VALUES ('order', sls_order_dt), ('shipping', sls_ship_dt), ('due', sls_due_dt))
            v(field_name, raw_value)
),

parsed AS (
    SELECT
        *,
        CASE
            WHEN raw_value > 0 AND LEN(CONVERT(varchar(11), raw_value)) = 8
                THEN TRY_CONVERT(date, CONVERT(varchar(11), raw_value), 112)
        END AS parsed_date
    FROM raw_dates
),

classified AS (
    SELECT
        *,
        CASE
            WHEN raw_value IS NULL THEN 'missing' WHEN raw_value = 0 THEN 'zero'
            WHEN raw_value < 0 OR LEN(CONVERT(varchar(11), raw_value)) <> 8 THEN 'malformed'
            WHEN parsed_date IS NULL THEN 'invalid_calendar'
            WHEN parsed_date < '19000101' OR parsed_date > '20501231' THEN 'outside_1900_2050'
            ELSE 'valid_in_range'
        END AS classification
    FROM parsed
)

SELECT TOP (10)
    'date_samples' AS audit_section,
    sls_ord_num,
    sls_prd_key,
    field_name,
    raw_value,
    classification,
    parsed_date
FROM classified
WHERE classification <> 'valid_in_range'
ORDER BY classification ASC, raw_value DESC, sls_ord_num, sls_prd_key FOR JSON PATH,
INCLUDE_NULL_VALUES;

SELECT
    'silver_dates' AS audit_section,
    v.field_name,
    SUM(CASE WHEN v.d IS NULL THEN 1 ELSE 0 END) AS nulls,
    SUM(CASE WHEN v.d < '19000101' OR v.d > '20501231' THEN 1 ELSE 0 END) AS outside_1900_2050
FROM silver.crm_sales_details
CROSS APPLY
    (VALUES ('order', sls_order_dt), ('shipping', sls_ship_dt), ('due', sls_due_dt))
        v(field_name, d)
GROUP BY v.field_name
ORDER BY v.field_name FOR JSON PATH;

SELECT
    'chronology' AS audit_section,
    COUNT(*) AS total,
    SUM(CASE WHEN sls_order_dt > sls_ship_dt THEN 1 ELSE 0 END) AS order_after_shipping,
    SUM(CASE WHEN sls_order_dt > sls_due_dt THEN 1 ELSE 0 END) AS order_after_due,
    SUM(CASE WHEN sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt THEN 1 ELSE 0 END)
        AS either_violation,
    SUM(CASE WHEN sls_order_dt = sls_ship_dt THEN 1 ELSE 0 END) AS same_day_order_shipping,
    SUM(CASE WHEN sls_order_dt = sls_due_dt THEN 1 ELSE 0 END) AS same_day_order_due,
    SUM(CASE WHEN sls_order_dt = sls_ship_dt AND sls_order_dt = sls_due_dt THEN 1 ELSE 0 END)
        AS all_same_day,
    SUM(CASE WHEN sls_order_dt IS NULL OR sls_ship_dt IS NULL THEN 1 ELSE 0 END)
        AS order_shipping_not_comparable,
    SUM(CASE WHEN sls_order_dt IS NULL OR sls_due_dt IS NULL THEN 1 ELSE 0 END)
        AS order_due_not_comparable
FROM silver.crm_sales_details FOR JSON PATH;

; WITH first_versions AS (
    SELECT
        prd_key,
        MIN(prd_start_dt) AS first_start
    FROM silver.crm_prd_info
    GROUP BY prd_key
),

gaps AS (
    SELECT
        s.*,
        f.first_start,
        DATEDIFF(DAY, s.sls_order_dt, f.first_start) AS days_before
    FROM silver.crm_sales_details s JOIN first_versions f ON f.prd_key = s.sls_prd_key
    WHERE s.sls_order_dt < f.first_start
)

SELECT
    'history_summary' AS audit_section,
    COUNT(*) AS transactions,
    COUNT(DISTINCT sls_prd_key) AS products,
    COUNT(DISTINCT sls_ord_num) AS orders,
    MIN(sls_order_dt) AS earliest_sale,
    MAX(sls_order_dt) AS latest_sale,
    MIN(days_before) AS minimum_days_before,
    MAX(days_before) AS maximum_days_before,
    SUM(CONVERT(bigint, sls_sales)) AS sales_amount
FROM gaps
FOR JSON PATH;

; WITH first_versions AS (
    SELECT
        prd_key,
        MIN(prd_start_dt) AS first_start
    FROM silver.crm_prd_info
    GROUP BY prd_key
),

gaps AS (
    SELECT
        s.*,
        f.first_start,
        DATEDIFF(DAY, s.sls_order_dt, f.first_start) AS days_before
    FROM silver.crm_sales_details s JOIN first_versions f ON f.prd_key = s.sls_prd_key
    WHERE s.sls_order_dt < f.first_start
)

SELECT
    'history_by_year' AS audit_section,
    YEAR(sls_order_dt) AS sales_year,
    COUNT(*) AS transactions,
    COUNT(DISTINCT sls_prd_key) AS products,
    SUM(CONVERT(bigint, sls_sales)) AS sales_amount
FROM gaps
GROUP BY YEAR(sls_order_dt)
ORDER BY sales_year FOR JSON PATH;

; WITH first_versions AS (
    SELECT
        prd_key,
        MIN(prd_start_dt) AS first_start
    FROM silver.crm_prd_info
    GROUP BY prd_key
),

gaps AS (
    SELECT
        s.*,
        f.first_start,
        DATEDIFF(DAY, s.sls_order_dt, f.first_start) AS days_before
    FROM silver.crm_sales_details s JOIN first_versions f ON f.prd_key = s.sls_prd_key
    WHERE s.sls_order_dt < f.first_start
)

SELECT
    'history_by_product_year' AS audit_section,
    sls_prd_key,
    YEAR(sls_order_dt) AS sales_year,
    first_start,
    COUNT(*) AS transactions,
    MIN(sls_order_dt) AS earliest_sale,
    MAX(sls_order_dt) AS latest_sale,
    MIN(days_before) AS min_days_before,
    MAX(days_before) AS max_days_before,
    SUM(CONVERT(bigint, sls_sales)) AS sales_amount
FROM gaps
GROUP BY sls_prd_key, YEAR(sls_order_dt), first_start
ORDER BY transactions DESC, sls_prd_key, sales_year FOR JSON PATH;

; WITH first_versions AS (
    SELECT
        prd_key,
        MIN(prd_start_dt) AS first_start
    FROM silver.crm_prd_info
    GROUP BY prd_key
),

gaps AS (
    SELECT
        s.*,
        f.first_start,
        DATEDIFF(DAY, s.sls_order_dt, f.first_start) AS days_before
    FROM silver.crm_sales_details s JOIN first_versions f ON f.prd_key = s.sls_prd_key
    WHERE s.sls_order_dt < f.first_start
)

SELECT TOP (10)
    'history_samples' AS audit_section,
    sls_ord_num,
    sls_prd_key,
    sls_order_dt,
    first_start,
    days_before,
    sls_sales
FROM gaps
ORDER BY days_before DESC, sls_ord_num, sls_prd_key FOR JSON PATH;

; WITH matches AS (
    SELECT
        s.*,
        (
            SELECT COUNT(*) FROM silver.crm_prd_info p
            WHERE p.prd_key = s.sls_prd_key
        ) AS key_matches,
        (
            SELECT COUNT(*)
            FROM silver.crm_prd_info p
            WHERE
                p.prd_key = s.sls_prd_key AND s.sls_order_dt >= p.prd_start_dt
                AND (s.sls_order_dt <= p.prd_end_dt OR p.prd_end_dt IS NULL)
        ) AS temporal_matches
    FROM silver.crm_sales_details s
)

SELECT
    'join_impact' AS audit_section,
    COUNT(*) AS sales_rows,
    SUM(key_matches) AS key_only_join_rows,
    SUM(temporal_matches) AS temporal_inner_join_rows,
    SUM(CASE WHEN temporal_matches = 0 THEN 1 ELSE 0 END) AS unmatched_temporal,
    SUM(CASE WHEN temporal_matches > 1 THEN 1 ELSE 0 END) AS ambiguous_temporal,
    SUM(CASE WHEN key_matches = 0 THEN 1 ELSE 0 END) AS missing_product_keys,
    SUM(CASE WHEN temporal_matches = 0 THEN CONVERT(bigint, sls_sales) ELSE 0 END)
        AS unmatched_temporal_sales
FROM matches FOR JSON PATH;

; WITH paired AS (
    SELECT
        b.sls_ord_num,
        b.sls_prd_key,
        b.sls_quantity AS raw_quantity,
        s.sls_quantity AS silver_quantity,
        b.sls_sales AS raw_sales,
        s.sls_sales AS silver_sales,
        b.sls_price AS raw_price,
        s.sls_price AS silver_price,
        s.dwh_create_date,
        CASE WHEN EXISTS (
            SELECT b.sls_sales
            EXCEPT
            SELECT s.sls_sales
        ) THEN 1
        ELSE 0 END
            AS sales_changed,
        CASE WHEN EXISTS (
            SELECT b.sls_price
            EXCEPT
            SELECT s.sls_price
        ) THEN 1
        ELSE 0 END
            AS price_changed
    FROM bronze.crm_sales_details b JOIN silver.crm_sales_details s
        ON
            CONVERT(varbinary(100), TRIM(b.sls_ord_num)) = CONVERT(varbinary(100), s.sls_ord_num)
            AND CONVERT(varbinary(100), TRIM(b.sls_prd_key))
            = CONVERT(varbinary(100), s.sls_prd_key)
),

corrected AS (
    SELECT
        *,
        CASE
            WHEN sales_changed = 1
                THEN CASE
                    WHEN raw_sales IS NULL THEN 'missing_sales'
                    WHEN raw_sales = 0 THEN 'zero_sales' WHEN
                        raw_sales < 0
                        THEN 'negative_sales' ELSE
                        'inconsistent_positive_sales'
                END
            WHEN raw_price IS NULL THEN 'missing_price' WHEN
                raw_price < 0
                THEN 'negative_price'
            ELSE 'other'
        END AS correction_rule
    FROM paired
    WHERE sales_changed = 1 OR price_changed = 1
)

SELECT
    'correction_summary' AS audit_section,
    correction_rule,
    COUNT(*) AS rows,
    SUM(COALESCE(CONVERT(bigint, raw_sales), 0)) AS raw_known_sales,
    SUM(CONVERT(bigint, silver_sales)) AS corrected_sales
FROM corrected
GROUP BY correction_rule
ORDER BY correction_rule FOR JSON PATH;

; WITH paired AS (
    SELECT
        b.sls_ord_num,
        b.sls_prd_key,
        b.sls_quantity AS raw_quantity,
        s.sls_quantity AS silver_quantity,
        b.sls_sales AS raw_sales,
        s.sls_sales AS silver_sales,
        b.sls_price AS raw_price,
        s.sls_price AS silver_price,
        s.dwh_create_date,
        CASE WHEN EXISTS (
            SELECT b.sls_sales
            EXCEPT
            SELECT s.sls_sales
        ) THEN 1
        ELSE 0 END
            AS sales_changed,
        CASE WHEN EXISTS (
            SELECT b.sls_price
            EXCEPT
            SELECT s.sls_price
        ) THEN 1
        ELSE 0 END
            AS price_changed
    FROM bronze.crm_sales_details b JOIN silver.crm_sales_details s
        ON
            CONVERT(varbinary(100), TRIM(b.sls_ord_num)) = CONVERT(varbinary(100), s.sls_ord_num)
            AND CONVERT(varbinary(100), TRIM(b.sls_prd_key))
            = CONVERT(varbinary(100), s.sls_prd_key)
),

corrected AS (
    SELECT
        *,
        CASE
            WHEN sales_changed = 1
                THEN CASE
                    WHEN raw_sales IS NULL THEN 'missing_sales'
                    WHEN raw_sales = 0 THEN 'zero_sales' WHEN
                        raw_sales < 0
                        THEN 'negative_sales' ELSE
                        'inconsistent_positive_sales'
                END
            WHEN raw_price IS NULL THEN 'missing_price' WHEN
                raw_price < 0
                THEN 'negative_price'
            ELSE 'other'
        END AS correction_rule
    FROM paired
    WHERE sales_changed = 1 OR price_changed = 1
)

SELECT
    'correction_trace' AS audit_section,
    *
FROM corrected
ORDER BY correction_rule, sls_ord_num, sls_prd_key
FOR JSON PATH, INCLUDE_NULL_VALUES;

; WITH paired AS (
    SELECT
        b.sls_ord_num,
        b.sls_prd_key,
        b.sls_quantity AS raw_quantity,
        s.sls_quantity AS silver_quantity,
        b.sls_sales AS raw_sales,
        s.sls_sales AS silver_sales,
        b.sls_price AS raw_price,
        s.sls_price AS silver_price,
        s.dwh_create_date,
        CASE WHEN EXISTS (
            SELECT b.sls_sales
            EXCEPT
            SELECT s.sls_sales
        ) THEN 1
        ELSE 0 END
            AS sales_changed,
        CASE WHEN EXISTS (
            SELECT b.sls_price
            EXCEPT
            SELECT s.sls_price
        ) THEN 1
        ELSE 0 END
            AS price_changed
    FROM bronze.crm_sales_details b JOIN silver.crm_sales_details s
        ON
            CONVERT(varbinary(100), TRIM(b.sls_ord_num)) = CONVERT(varbinary(100), s.sls_ord_num)
            AND CONVERT(varbinary(100), TRIM(b.sls_prd_key))
            = CONVERT(varbinary(100), s.sls_prd_key)
),

corrected AS (
    SELECT
        *,
        CASE
            WHEN sales_changed = 1
                THEN CASE
                    WHEN raw_sales IS NULL THEN 'missing_sales'
                    WHEN raw_sales = 0 THEN 'zero_sales' WHEN
                        raw_sales < 0
                        THEN 'negative_sales' ELSE
                        'inconsistent_positive_sales'
                END
            WHEN raw_price IS NULL THEN 'missing_price' WHEN
                raw_price < 0
                THEN 'negative_price'
            ELSE 'other'
        END AS correction_rule
    FROM paired
    WHERE sales_changed = 1 OR price_changed = 1
)

SELECT
    'traceability_checks' AS audit_section,
    (SELECT COUNT(*) FROM paired) AS paired_rows,
    (SELECT COUNT(*) FROM corrected) AS corrected_rows,
    (
        SELECT COUNT(*) FROM paired
        WHERE raw_quantity <> silver_quantity
    ) AS quantity_changes,
    (
        SELECT COUNT(*) FROM paired
        WHERE
            raw_price > 0
            AND CONVERT(bigint, silver_sales) <> CONVERT(bigint, raw_price) * raw_quantity
    ) AS rebuild_failures,
    (
        SELECT COUNT(*)
        FROM paired
        WHERE
            (raw_price IS NULL OR raw_price <= 0)
            AND (raw_sales IS NULL OR raw_quantity <= 0 OR raw_sales % NULLIF(raw_quantity, 0) <> 0 OR silver_price <> raw_sales / NULLIF(raw_quantity, 0))
    ) AS derivation_failures,
    (
        SELECT COUNT(*) FROM paired
        WHERE
            silver_sales IS NULL
            OR silver_price IS NULL
            OR CONVERT(bigint, silver_sales) <> CONVERT(bigint, silver_price) * silver_quantity
    ) AS silver_amount_failures,
    (
        SELECT COUNT(*) FROM (SELECT
            TRIM(sls_ord_num) AS o,
            TRIM(sls_prd_key) AS p
        FROM bronze.crm_sales_details
        GROUP BY TRIM(sls_ord_num), TRIM(sls_prd_key)
        HAVING COUNT(*) > 1) q
    ) AS duplicate_bronze_keys,
    (
        SELECT COUNT(*) FROM (SELECT
            sls_ord_num,
            sls_prd_key
        FROM silver.crm_sales_details
        GROUP BY sls_ord_num, sls_prd_key
        HAVING COUNT(*) > 1) q
    ) AS duplicate_silver_keys
FOR JSON PATH;

; WITH comparison AS (
    SELECT
        v.field_name,
        v.raw_value,
        v.silver_date,
        CASE
            WHEN v.raw_value > 0 AND LEN(CONVERT(varchar(11), v.raw_value)) = 8
                THEN TRY_CONVERT(date, CONVERT(varchar(11), v.raw_value), 112)
        END AS expected_date
    FROM bronze.crm_sales_details b JOIN silver.crm_sales_details s
        ON s.sls_ord_num = TRIM(b.sls_ord_num) AND s.sls_prd_key = TRIM(b.sls_prd_key)
    CROSS APPLY
        (
            VALUES ('order', b.sls_order_dt, s.sls_order_dt),
            ('shipping', b.sls_ship_dt, s.sls_ship_dt),
            ('due', b.sls_due_dt, s.sls_due_dt)
        ) v(field_name, raw_value, silver_date)
)

SELECT
    'date_reconciliation' AS audit_section,
    field_name,
    COUNT(*) AS rows_compared,
    SUM(CASE
        WHEN
            silver_date <> expected_date OR (silver_date IS NULL AND expected_date IS NOT NULL)
            OR (silver_date IS NOT NULL AND expected_date IS NULL) THEN 1
        ELSE 0
    END) AS mismatches
FROM comparison
GROUP BY field_name
ORDER BY field_name FOR JSON PATH;
