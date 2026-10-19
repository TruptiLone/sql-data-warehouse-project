# RetailFlow 360 — Data Warehouse Implementation & Data Quality Guide

**Documentation status:** Bronze and all six Silver tables implemented and tested locally; Gold is **not built yet**.  
**Last project update:** 2026-10-19.  
**Evidence basis:** Codex execution summaries shared during development, the earlier source DDL, and the Udemy instructor's transformation lesson. **The local files under `local-sqlserver/scripts/` are the source of truth for exact executable logic.** The snippets below explain important patterns; they are not a verbatim copy of unpushed scripts.

## 1. Purpose and business context

RetailFlow 360 is a portfolio data-engineering project that converts raw CRM and ERP extracts into trusted, joinable datasets for retail customer, product, and sales analytics.

Business questions the warehouse is intended to support include:
- Who are the customers, where are they located, and which customer segments purchase which products?
- How much revenue and quantity are sold by date, customer, product, and category?
- How can historical product versions be represented without losing or duplicating sales?
- How can data quality be verified from raw CSV ingestion through analytics-ready tables?

The project demonstrates **ingestion, data profiling, cleansing, standardization, integration, quality assurance, repeatable loading, and eventually dimensional modeling**. The Gold layer and its analytics are planned, not yet delivered.

### Architecture

```text
CRM CSVs                         ERP CSVs
cust_info                       CUST_AZ12
prd_info                        LOC_A101
sales_details                   PX_CAT_G1V2
       \                          /
        └──── Local file ingestion ────┘
                      │
                      ▼
        SQL Server DataWarehouse
          bronze.*  [raw fidelity]
                      │
          profile → transform → validate
                      ▼
          silver.*  [cleaned, joinable]
                      │
               [not built yet]
                      ▼
          gold.dim_customers
          gold.dim_products
          gold.fact_sales
                      │
               Future reporting
```

## 2. What a data warehouse and its layers do

A **data warehouse** brings operational data from multiple systems into a consistent, queryable model for analytical reporting. The original applications prioritize transactions; the warehouse prioritizes trustworthy historical analysis.

| Layer | Purpose | What happens in this project |
| --- | --- | --- |
| **Bronze** | Preserve source records for traceability and reprocessing | Load six CSV files with source structure/values intact; record counts and check raw quality |
| **Silver** | Produce consistent, clean, joinable records | Fix invalid values, standardize codes/keys, deduplicate CRM customers, type dates, reconcile across systems, record exceptions |
| **Gold** | Provide business-facing dimensional models and stable metrics | **Planned:** customer/product dimensions and sales fact with safe historical joins |

**Important distinction:** A Bronze anomaly is not necessarily a bad load. The raw source may contain inconsistent keys, invalid values, or duplicates; Bronze preserves them so Silver transformations can be audited.

## 3. Local environment and safeguards

| Item | Implementation |
| --- | --- |
| Version control | GitHub repository `sql-data-warehouse-project` |
| Local project | `local-sqlserver/` |
| Development environment | macOS Apple Silicon, VS Code, Microsoft SQL Server (mssql) extension, Codex |
| Runtime | Docker Desktop with Rosetta/x86-64 emulation |
| Database engine | SQL Server 2022 Developer (reported build 16.0.4305.5) |
| Container | `retailflow-sql-local` |
| Local endpoint | `127.0.0.1:14333` |
| Database | `DataWarehouse` |
| Schemas | `bronze`, `silver`, `gold` |
| Persistent data | Docker named volume; `compose.yaml` manages runtime configuration |

SQL Server running as an AMD64 image on Apple Silicon is **not officially supported**; it worked in this development session, but another machine or update may behave differently. Re-test connectivity after Docker upgrades.

**Never commit** `local-sqlserver/.env`, credentials, source CSV files, or generated import copies. The dataset directories and local secrets are Git-ignored. The Azure `DataWarehouse` is separate and was not accessed during local development.

### Files and folders

```text
sql-data-warehouse-project/
├── scripts/                          # Earlier Azure-oriented SQL work; preserved
└── local-sqlserver/
    ├── compose.yaml
    ├── .env.example
    ├── .env                          # Local secret; ignored by Git
    ├── datasets/                     # Source CSVs; ignored by Git
    │   ├── source_crm/
    │   └── source_erp/
    ├── scripts/
    │   ├── init_database.sql
    │   ├── bronze/
    │   │   ├── ddl_bronze.sql
    │   │   ├── load_bronze.py
    │   │   ├── load_bronze.sql
    │   │   └── quality_checks.sql
    │   └── silver/
    │       ├── ddl_crm.sql
    │       ├── load_crm.sql
    │       ├── run_crm.py
    │       ├── ddl_sales.sql
    │       ├── load_sales.sql
    │       ├── run_sales.py
    │       ├── audit_sales.sql
    │       ├── ddl_erp.sql
    │       ├── load_erp.sql
    │       ├── run_erp.py
    │       ├── quality_erp.sql
    │       ├── README.md
    │       ├── SALES.md
    │       ├── SALES_AUDIT.md
    │       └── ERP.md
    └── docs/
        └── IMPLEMENTATION_GUIDE.md
```

Other profiling, verification, and documentation files exist in the local Silver folder. The exact inventory should be confirmed before the next commit.

## 4. Chronological implementation log

1. **Provision local tooling.** Docker Desktop installed; Rosetta enabled; 8 GB Docker VM memory. Basic AMD64 container execution confirmed.
2. **Start SQL Server safely.** Switched from an error-prone manual `docker run` to project-local Docker Compose, a secret `.env`, persistent named volume, and localhost-only port mapping. Codex verified `SELECT @@VERSION` and a healthy running container.
3. **Connect VS Code.** Microsoft SQL Server (mssql) extension connected to local `127.0.0.1` port `14333` using SQL Login; earlier Azure profile was kept separate.
4. **Initialize database.** Created local `DataWarehouse` and `bronze`, `silver`, `gold` schemas using an idempotent script. Initial user table count: zero.
5. **Define Bronze tables.** Created six empty tables (32 original source columns in total); DDL verified against original definitions and source headers.
6. **Load Bronze datasets.** Used a CSV-aware source count, read-only dataset bind mount, SQL loading scripts and Python runner. Handled final CSV rows with no newline through lossless Unicode import copies. Verified complete record fidelity and rerun behavior.
7. **Build Silver CRM customers/products.** Profiled raw values, transformed, inserted, reconciled counts, and tested reruns.
8. **Build Silver CRM sales.** Converted dates, repaired documented monetary anomalies, validated chronology and arithmetic, preserved unresolved historical exceptions.
9. **Build Silver ERP customers/location/categories.** Standardized source identifiers and categories, verified CRM/ERP linkability, inserted, and reconciled counts.
10. **Gold model.** Not yet implemented.

## 5. Bronze: CSV ingestion, profiling, and validation

### Files and loaded record counts

| Source | Bronze table | Source data rows | Loaded rows | Result |
| --- | --- | ---: | ---: | --- |
| CRM customer | `bronze.crm_cust_info` | 18,494 | 18,494 | PASS |
| CRM product | `bronze.crm_prd_info` | 397 | 397 | PASS |
| CRM sales | `bronze.crm_sales_details` | 60,398 | 60,398 | PASS |
| ERP customer | `bronze.erp_cust_az12` | 18,484 | 18,484 | PASS |
| ERP location | `bronze.erp_loc_a101` | 18,484 | 18,484 | PASS |
| ERP product category | `bronze.erp_px_cat_g1v2` | 37 | 37 | PASS |
| **Total** | | **116,294** | **116,294** | **PASS** |

### Granular Bronze workflow

1. **Inspect each source file:** header, encoding, quoting, delimiter, field shape, and CSV-aware row count (not just newline count).
2. **Inspect table DDL:** verify column name, order, type, and length. The six tables contain 32 columns in total.
3. **Make files available to SQL Server:** use a read-only Docker bind mount; preserve the database's persistent storage volume.
4. **Handle special file formatting:** some source CSVs have no final newline. The import process used lossless Unicode copies so the final record was not lost.
5. **Load into empty Bronze tables:** the runner plus transactional SQL loader imported raw records without cleaning them.
6. **Reconcile:** source record counts and SQL table counts must match; compare first and last records and repeated-record occurrence counts.
7. **Check reruns:** re-execution skips already populated, validated tables rather than appending duplicates.
8. **Record source anomalies without changing Bronze:** identify invalid IDs, duplicates, unexpected NULLs, and possible referential issues.

### Bronze findings

- CRM customers: **4 NULL customer IDs**, **5 duplicated ID groups**, corresponding to **6 excess occurrences**.
- Other source identifier fields: no reported NULLs.
- CRM sales: no repeated order/product combinations.
- All six source files: no full-row duplicates, import-count mismatches, or successful-load errors.
- The entire original Bronze population (**116,294 rows**) remained unchanged through subsequent Silver processing.

Raw customer counts differ from Silver by 10 rows because the curated customer master excludes four NULL IDs and consolidates six excess occurrences.

## 6. How Silver transformations are performed

Every Silver dataset follows the same logical process:

```text
Bronze source (read-only)
       │
       ▼
1. PROFILE      Inspect NULLs, duplicates, patterns, ranges, cardinality
       │
       ▼
2. DEFINE RULES Decide whether to normalize, repair, retain, or flag
       │
       ▼
3. PREVIEW      SELECT raw value beside transformed value
       │
       ▼
4. LOAD         INSERT transformed rows into corresponding Silver table
       │
       ▼
5. VALIDATE     Compare counts, uniqueness, values, joins, business rules
       │
       ▼
6. RERUN        Ensure no duplicate insert or accidental timestamp changes
       │
       ▼
7. DOCUMENT     Record affected counts, unresolved anomalies, file paths
```

### Data quality before transformation

Read-only profiling often starts with patterns such as:

```sql
-- Example: identify missing/duplicate CRM IDs before cleaning.
SELECT COUNT(*) AS source_rows,
       SUM(CASE WHEN cst_id IS NULL THEN 1 ELSE 0 END) AS null_ids
FROM bronze.crm_cust_info;

SELECT cst_id, COUNT(*) AS occurrence_count
FROM bronze.crm_cust_info
WHERE cst_id IS NOT NULL
GROUP BY cst_id
HAVING COUNT(*) > 1;
```

For small-domain fields (gender, country, maintenance) compare `SELECT DISTINCT` values and frequencies. For dates, inspect malformed, sentinel, out-of-range, and chronologically inconsistent records. For monetary values, compare sales amount against quantity multiplied by unit price.

### Transform: preview the mapping first

An illustrative ERP gender mapping:

```sql
SELECT
    gen AS source_gender,
    CASE
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
        ELSE 'n/a'
    END AS silver_gender
FROM bronze.erp_cust_az12;
```

The point of the side-by-side preview is **auditability**: know exactly which values change and how many records each rule affects before writing rows.

### Insert into Silver and verify

A conceptual **initial-load-only** SQL pattern (illustrative, **not** the exact unpushed loader source) is:

```sql
USE DataWarehouse;
GO

-- Inspect target first. Only load if not already populated.
IF NOT EXISTS (SELECT 1 FROM silver.erp_cust_az12)
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                 ELSE cid END,
            CASE WHEN bdate > CAST(GETDATE() AS date) THEN NULL
                 ELSE bdate END,
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'Male'
                ELSE 'n/a'
            END
        FROM bronze.erp_cust_az12;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
```

**Caution:** This is a learning example, not the project's exact runnable loader. The real source files must be used to confirm column lists, metadata fields, reconciliation checks, safe reload behavior, and date policy. The implementation reported **no destructive refresh, no duplicate inserts, and no unnecessary timestamp changes** on reruns. Skipping populated tables prevents duplication but alone does not solve changed-source updates; incremental refresh design is future work.

### Verify the Silver results

- **Counts:** source vs destination plus explained deduplication/exclusions.
- **Uniqueness:** intended business keys are non-NULL and unique where required.
- **Values:** compare complete transformed rows or independently recomputed expected values, not only aggregate counts.
- **Domain:** gender, country, category, dates, costs, prices fall into documented valid patterns.
- **Referential coverage:** normalized ERP customer IDs join CRM customers; product category IDs join appropriately or are flagged.
- **Rerun checks:** a second execution does not append duplicates or change stable loaded records/timestamps.
- **Immutability:** Bronze totals and previously validated Silver tables stay unchanged.

## 7. Silver CRM customer transformation

**Source:** `bronze.crm_cust_info` → **Target:** `silver.crm_cust_info`

| Step | Actual finding or action |
| --- | --- |
| Profile | 18,494 raw records; 4 NULL IDs; 5 duplicated ID groups and 6 excess occurrences |
| Transform | Exclude NULL-ID rows from curated customer master; choose a consistent winner for repeated valid IDs; trim strings; standardize gender and marital-status values |
| Insert | Load cleaned, deduplicated customer rows using local loader; preserve source Bronze table |
| Validate | **18,484 Silver rows**; unique valid customer IDs; independently checked transformations; rerun preserved values and load timestamps |

The precise duplicate tie-break rule belongs to `local-sqlserver/scripts/silver/load_crm.sql` and related profiling/quality files. **Do not assume an arbitrary `ROW_NUMBER` order:** a deterministic and business-defensible sort matters.

**Count reconciliation:** 18,494 − 4 NULL-ID rows − 6 duplicate excess occurrences = **18,484**.

## 8. Silver CRM product transformation

**Source:** `bronze.crm_prd_info` → **Target:** `silver.crm_prd_info`

| Step | Actual finding or action |
| --- | --- |
| Profile | 397 source product-version records; inspect keys, names, costs, category/line codes, and version dates |
| Transform | Normalize product and category identifiers; standardize product metadata; replace **2 NULL costs with zero** (project cleaning assumption); repair **200 invalid end dates** while retaining history |
| Insert | Keep all 397 product-version records, including historical rows |
| Validate | **397 Silver rows**: **102 closed versions** and **295 current versions**; transformed values verified; rerun stable |

**Important:** A cost of zero may mean “unknown cost” rather than free inventory. Document that assumption. Product history requires validation for temporal gaps, overlaps, and sales occurring before the first known version. The reported 200 repaired dates should be reviewed in the exact implementation to ensure valid non-overlapping intervals.

## 9. Silver CRM sales transformation and quality audit

**Source:** `bronze.crm_sales_details` → **Target:** `silver.crm_sales_details`

### A. Profile

60,398 source sales rows. The instructor's checks included invalid dates, order/ship/due chronology, `sales = quantity × price`, NULLs, and nonpositive monetary fields.

### B. Date transformation

Convert the three integer `YYYYMMDD` columns to actual `DATE` values using SQL Server style 112 and safe `TRY_CONVERT`. For example:

```sql
TRY_CONVERT(date, CAST(sls_order_dt AS varchar(20)), 112)
```

| Date check | Result |
| --- | ---: |
| Zero/sentinel order dates | 17 → NULL |
| Malformed order dates | 2 (examples `5489`, `32154`) → NULL |
| Invalid correctly formed calendar dates | 0 |
| Dates outside 1900–2050 | 0 |
| Invalid shipping dates | 0 |
| Invalid due dates | 0 |
| Order date later than shipping date or due date | 0 |
| Same-day order/ship or order/due | 0 |
| Orders with unknown dates | **19**, retained and not chronologically comparable |

Date comparisons use valid converted values; NULLs do not establish a chronology.

### C. Monetary transformation and source traceability

The independent audit found **35 distinct Bronze sales rows** with at least one instructor monetary violation. Codex reported **23 amount repairs** plus **12 price repairs**, reducing monetary inconsistencies from 35 distinct failing rows to zero.

| Exact quality condition | Bronze violations | Silver violations |
| --- | ---: | ---: |
| Sales amount ≠ quantity × price | 20 | 0 |
| NULL sales | 8 | 0 |
| NULL quantity | 0 | 0 |
| NULL price | 7 | 0 |
| Any NULL monetary field | 15 | 0 |
| Sales ≤ 0 | 5 | 0 |
| Quantity ≤ 0 | 0 | 0 |
| Price ≤ 0 | 5 | 0 |
| Any nonpositive monetary field | 10 | 0 |
| **Distinct failing rows (conditions overlap)** | **35** | **0** |

Example original-to-cleaned values:
- `SO51259 / WB-H098`: price NULL, sales 10, quantity 2 → calculated price 5.
- `SO58335 / TI-M823`: sales 35 with quantity 2 and price 35 → sales corrected to 70.
- `SO61548 / CA-1098`: sales NULL, quantity 1, price 9 → sales 9.
- `SO61570 / CA-1098`: sales −18, quantity 1, price 9 → sales 9.
- `SO57804 / BK-M38S-40`: price −769, sales 769, quantity 1 → price 769.

These changes are **traceable to unchanged Bronze rows**, but whether negative amounts represent errors or genuine refunds/returns requires business confirmation. The cleaning logic intentionally did not blindly apply `ABS()` everywhere.

### D. Insert and validate

- Inserted **60,398 of 60,398** rows: no exclusions or duplicates.
- Independently compared transformed rows and validated 14 reported SQL quality checks.
- Re-execution preserved values and existing load timestamps.
- The exact instructor monetary query returned **zero Silver records**:

```sql
SELECT *
FROM silver.crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0;
```

### E. Unresolved historical product issue (do not “fix” silently)

**18,410 sales** predate the first recorded product version, spanning 119 products:

| Sales year | Affected rows |
| --- | ---: |
| 2010 | 14 |
| 2011 | 1,020 |
| 2012 | 1,333 |
| 2013 | 16,043 |

One example is `SO46676 / BK-R64Y-42`, preceding its product's earliest version by 185 days. A temporal **inner join** would omit **18,429** fact rows (the 18,410 plus 19 unknown-date orders). A naive product-business-key join could inflate **60,398** transactions to **89,818** rows because products have multiple versions.

**Gold design requirement:** preserve every sales record; use a **LEFT temporal lookup** with zero-or-one product-version match per fact, explicit unmatched-status reporting, and a considered “unknown/unresolved product version” design. No backdating or arbitrary version substitution.

## 10. Silver ERP customer transformation

**Source:** `bronze.erp_cust_az12` → **Target:** `silver.erp_cust_az12`

### Profile and transform

1. **CID normalization:** remove the initial `NAS` prefix only when present. **11,042** identifiers affected.
2. **Birthdate validity:** convert **16 future birthdates to NULL**; retain **22 birthdates older than 100 years** as potentially valid but flagged. Oldest reported in the group: 1916-02-10; most recent in that group: 1926-09-07.
3. **Gender normalization:** trim and case-normalize abbreviations/full names to `Male`, `Female`, or `n/a`; **1,485** rows affected.
4. **Join check:** every standardized ERP CID matches a CRM customer key.

Illustrative transformation snippets:

```sql
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
     ELSE cid END AS cid,
CASE WHEN bdate > CAST(GETDATE() AS date) THEN NULL
     ELSE bdate END AS bdate,
CASE WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
     WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'Male'
     ELSE 'n/a' END AS gen
```

### Insert and validate

**18,484 Bronze → 18,484 Silver**, **18,484 distinct IDs**, **0 unmatched CRM IDs**, valid standardized domains and rerun stability. No source rows were removed.

## 11. Silver ERP location transformation

**Source:** `bronze.erp_loc_a101` → **Target:** `silver.erp_loc_a101`

### Profile and transform

1. **CID normalization:** remove hyphens to match CRM customer identifiers; **18,484** rows affected.
2. **Country standardization:** trim whitespace, map `DE` to Germany and `US`/`USA` to United States, and represent blank/NULL as `n/a`; **4,994** values changed. **The actual file uses `DE`, not the instructor's example `D`.**
3. **Join check:** verify standardized location CIDs match CRM customers.

Illustrative expressions:

```sql
REPLACE(cid, '-', '') AS cid,
CASE
    WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
    WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
    WHEN NULLIF(TRIM(cntry), '') IS NULL THEN 'n/a'
    ELSE TRIM(cntry)
END AS cntry
```

### Insert and validate

**18,484 Bronze → 18,484 Silver**, **18,484 distinct IDs**, **0 unmatched CRM IDs**, normalized countries and stable timestamps on rerun.

## 12. Silver ERP product category transformation

**Source:** `bronze.erp_px_cat_g1v2` → **Target:** `silver.erp_px_cat_g1v2`

### Profile, transform, and insert

- Check `id`, `cat`, `subcat`, and `maintenance` for empty values, unwanted whitespace, domain consistency, and duplicate keys.
- Instructor found this dataset already clean; our profile also required **0 attribute changes**.
- Still load it into Silver to maintain a consistent contract across all six tables.
- **37 Bronze → 37 Silver**, **37 distinct category IDs**; rerun verification passed.

### Explicit integration exception

ERP category key `CO_PD` (“Pedals”) lacks a matching CRM category; CRM `CO_PE` lacks a matching ERP key and affects **7 product versions**. These have **not** been arbitrarily equated.

**Gold design requirement:** investigate category-code ownership/meaning, decide on approved mapping or an explicit unknown category, and surface unmapped records in data quality reporting.

## 13. Final Silver reconciliation and controls

| Table | Bronze rows | Silver rows | Why |
| --- | ---: | ---: | --- |
| `crm_cust_info` | 18,494 | 18,484 | 4 NULL IDs removed; 6 excess ID occurrences consolidated |
| `crm_prd_info` | 397 | 397 | All product versions retained |
| `crm_sales_details` | 60,398 | 60,398 | All sales retained |
| `erp_cust_az12` | 18,484 | 18,484 | No exclusions |
| `erp_loc_a101` | 18,484 | 18,484 | No exclusions |
| `erp_px_cat_g1v2` | 37 | 37 | No exclusions |
| **Total (table-row sum)** | **116,294** | **116,284** | **10 explained customer-row reductions** |

**Reported validation coverage:**
- Bronze: all six CSV record counts and row-level comparisons passed; rerunning did not append duplicates.
- CRM customer/product: **10 quality checks** passed; complete transformed-value comparison passed.
- CRM sales: **14 quality checks** passed; instructor monetary query yielded **0 violations**; chronology and date audits passed.
- ERP: count, identifier uniqueness, normalization, date, category integrity, and full transformation checks passed **with one documented category integration warning**.
- No subsequent work changed the 116,294 Bronze records; CRM Silver values and load timestamps stayed stable when ERP was loaded.

### Example diagnostic SQL (read-only)

```sql
USE DataWarehouse;
GO

-- Counts for six Silver tables.
SELECT 'crm_cust_info' AS table_name, COUNT(*) AS rows_count FROM silver.crm_cust_info
UNION ALL SELECT 'crm_prd_info', COUNT(*) FROM silver.crm_prd_info
UNION ALL SELECT 'crm_sales_details', COUNT(*) FROM silver.crm_sales_details
UNION ALL SELECT 'erp_cust_az12', COUNT(*) FROM silver.erp_cust_az12
UNION ALL SELECT 'erp_loc_a101', COUNT(*) FROM silver.erp_loc_a101
UNION ALL SELECT 'erp_px_cat_g1v2', COUNT(*) FROM silver.erp_px_cat_g1v2;

-- ERP customer IDs without CRM match (should be 0).
SELECT COUNT(*) AS unmatched_customer_ids
FROM silver.erp_cust_az12 AS e
LEFT JOIN silver.crm_cust_info AS c ON e.cid = c.cst_key
WHERE c.cst_key IS NULL;

-- Money-quality violations (should be 0).
SELECT COUNT(*) AS invalid_sales_rows
FROM silver.crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price
   OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0;
```

Use the project-specific quality scripts for full validation; these examples are only a subset.

## 14. Why our loading approach differs from the instructor

The course demonstrates a full refresh that **TRUNCATEs each Silver table before INSERT**. That prevents accumulating duplicates but discards and reloads rows each time. Our local implementation instead reported a **non-destructive, safely rerunnable load**: a second execution left Silver rows and load timestamps unchanged.

This choice protects existing work and reduces the risk of accidentally running a destructive script against the wrong environment. It also requires a future design for changed-source refreshes, which we have **not yet implemented**. Neither technique is universally correct; the appropriate choice depends on refresh cadence, audit requirements, and source change semantics.

## 15. Known limitations and pending decisions

| Issue | Status | Why it matters |
| --- | --- | --- |
| 19 unknown order dates | Preserved as NULL | No chronological placement; Gold needs missing-date policy |
| 18,410 sales before known product history | Unresolved | Historical temporal joins can lose sales |
| 7 product versions with `CO_PE` vs ERP `CO_PD` | Unresolved | Product-category enrichment may be missing |
| 35 monetary corrections | Consistent in Silver; business assumption pending | Negative amounts might mean genuine refunds |
| 2 product costs mapped NULL → 0 | Applied; business meaning pending | “Unknown cost” vs “zero cost” affects margin |
| 22 ERP birthdates over 100 years old | Retained | Flag as suspicious, not automatically impossible |
| 200 product end-date repairs | Executed; historical validity needs Gold review | Product effective-date joins depend on version timelines |
| Incremental/CDC pipeline | Not built | Current loaders are aimed at initial/repeatable development |
| Gold, analytics, CI/CD | Not built | Next project milestones |

## 16. Next steps and acceptance criteria

1. **Commit and push the current local Bronze/Silver milestone:** review `git status`, verify no secrets/datasets staged, commit only intended code/docs/config, and push only after reconciling upstream changes.
2. **Gold model design:** define grain and keys for `gold.dim_customers`, `gold.dim_products`, `gold.fact_sales`. Resolve one-to-many/history issues **before** coding.
3. **Preserve fact grain:** ensure **60,398** source sales produce **60,398** Gold fact records, not 18,429 missing or 89,818 duplicated.
4. **Explicit unknown relationships:** unresolved product-version, category, and date cases need documented handling and match-status metrics.
5. **Integration tests:** uniqueness, referential quality, count reconciliation, revenue totals, no temporal overlaps, and deterministic reruns.
6. **Future portfolio work:** architecture diagram, data catalog, business KPI queries, automated checks/CI, and clear local setup instructions for reviewers.

## 17. Reference scripts and reproducibility

Use the SQL and Python files in `local-sqlserver/scripts/` for executable operations. The key reference docs reported by Codex are:
- Bronze: `scripts/bronze/README.md` and `quality_checks.sql`.
- CRM customer/products: `scripts/silver/load_crm.sql`, `quality_checks.sql`, and related profiling files.
- Sales: `scripts/silver/load_sales.sql`, `quality_sales.sql`, `audit_sales.sql`, `SALES.md`, and `SALES_AUDIT.md`.
- ERP: `scripts/silver/load_erp.sql`, `quality_erp.sql`, and `ERP.md`.

**Maintenance rule:** update this guide when an implementation or business assumption changes. Numerical claims should always be rechecked against the runnable quality scripts; descriptive examples should not replace executable source code.
