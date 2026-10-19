# RetailFlow 360 — Data Warehouse Implementation & Data Quality Guide

**Documentation status:** Bronze and all six Silver tables implemented and tested locally; Gold is **not built yet**.  
**Last project update:** 2026-10-19.  
**Evidence basis:** Reviewed local SQL/Python source, read-only profiling and quality checks against the local Docker database, and preserved development reports. **The files under `local-sqlserver/scripts/` are the source of truth for exact executable logic.** Excerpts are labeled below; standalone examples are illustrative, not replacement loaders. Numeric results are a snapshot as of 2026-10-19, not guarantees for changed source data or a later date.

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
| **Bronze** | Preserve source records for traceability and reprocessing | Load six CSV files using the original typed DDL; preserve parsed field meaning and record counts, including anomalies |
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

Additional exact sources include `profile_crm.sql`, `profile_sales.sql`, `profile_erp.sql`, `quality_checks.sql`, and `quality_sales.sql`. See the linked script inventory in section 17. Personal inspection scratch files are not part of the supported loading workflow.

## 4. Chronological implementation log

1. **Provision local tooling.** The development notes record Docker Desktop, x86-64 emulation on Apple Silicon, and approximately 8 GB Docker VM memory. These are historical workstation details, not settings enforced by the repository.
2. **Start SQL Server safely.** Switched from an error-prone manual `docker run` to project-local Docker Compose, a secret `.env`, persistent named volume, and localhost-only port mapping. Codex verified `SELECT @@VERSION` and a healthy running container.
3. **Connect VS Code.** Microsoft SQL Server (mssql) extension connected to local `127.0.0.1` port `14333` using SQL Login; earlier Azure profile was kept separate.
4. **Initialize database.** Created local `DataWarehouse` and `bronze`, `silver`, `gold` schemas using an idempotent script. Initial user table count: zero.
5. **Define Bronze tables.** Created six empty tables (32 original source columns in total); DDL verified against original definitions and source headers.
6. **Load Bronze datasets.** Used a CSV-aware source count, read-only dataset bind mount, SQL loading scripts and Python runner. Handled final CSV rows with no newline through lossless Unicode import copies. Verified complete record fidelity and rerun behavior.
7. **Build Silver CRM customers/products.** Profiled raw values, transformed, inserted, reconciled counts, and tested reruns.
8. **Build Silver CRM sales.** Converted dates, repaired documented monetary anomalies, validated chronology and arithmetic, preserved unresolved historical exceptions.
9. **Build Silver ERP customers/location/categories.** Standardized customer/location values; preserved already-clean category attributes; reported unmatched category keys; inserted and reconciled counts.
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
4. **Handle special file formatting:** CRM customers, ERP customers, and ERP categories have no final newline. `load_bronze.py` writes UTF-16 CSV copies with a BOM, LF separators, and a final newline under ignored `datasets/.bulk/`, then reparses them to verify field equality. Original UTF-8 files remain untouched. SQL uses `FORMAT='CSV'`, `DATAFILETYPE='widechar'`, `ROWTERMINATOR='0x0a00'`, `FIRSTROW=2`, and `KEEPNULLS`; Linux rejected the earlier CODEPAGE option.
5. **Load into empty Bronze tables:** the runner plus transactional SQL loader imported raw records without cleaning them.
6. **Reconcile:** source record counts and SQL table counts must match; compare first and last records and repeated-record occurrence counts.
7. **Check reruns:** SQL skips any populated table without writing to it. Python subsequently compares every table with the source, including skipped tables; a mismatch raises an error and is not auto-repaired. SQL count checks occur before its transaction commits, but Python full-row validation occurs after commit.
8. **Record source anomalies without changing Bronze:** identify invalid IDs, duplicates, unexpected NULLs, and possible referential issues.

### Bronze findings

- CRM customers: **4 NULL customer IDs**, **5 duplicated ID groups**, corresponding to **6 excess occurrences**.
- Other source identifier fields: no reported NULLs.
- CRM sales: no repeated order/product combinations.
- All six source files: no full-row duplicates, import-count mismatches, or successful-load errors.
- The entire original Bronze population (**116,294 rows**) remained unchanged through subsequent Silver processing.

Bronze preserves typed source meaning, not CSV byte-for-byte storage: empty fields become NULL, dates/numbers use the original DDL types, and import encoding/line endings change only in derived copies.

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

The following are **exact excerpts** from `scripts/silver/load_erp.sql`, shown without surrounding guards and checks. They are **not standalone runnable loaders**. Use `run_erp.py` to execute the complete implementation.

```sql
;WITH normalized AS (
 SELECT CASE WHEN LEFT(TRIM(cid),3)='NAS' THEN SUBSTRING(TRIM(cid),4,50) ELSE TRIM(cid) END AS cid,
 CASE WHEN TRY_CONVERT(date,bdate)>@as_of THEN NULL ELSE TRY_CONVERT(date,bdate) END AS bdate,
 CAST(CASE UPPER(TRIM(gen)) WHEN 'M' THEN 'Male' WHEN 'MALE' THEN 'Male' WHEN 'F' THEN 'Female' WHEN 'FEMALE' THEN 'Female' ELSE 'n/a' END AS nvarchar(50)) AS gen
 FROM bronze.erp_cust_az12
) SELECT * INTO #erp_cust_az12 FROM normalized;
```

The actual initial insert includes the warehouse timestamp:

```sql
IF NOT EXISTS(SELECT 1 FROM silver.erp_cust_az12)
BEGIN
 INSERT silver.erp_cust_az12(cid,bdate,gen,dwh_create_date) SELECT *,SYSDATETIME() FROM #erp_cust_az12;
 PRINT 'Inserted silver.erp_cust_az12';
END
ELSE PRINT 'Preserved silver.erp_cust_az12; checking expected values.';
```

The complete loader starts a transaction **before** taking source/reference and exclusive target locks or inspecting target emptiness. `@as_of` is the database date captured at the start. It checks normalized IDs, inserts only into empty targets, then compares counts and complete expected/actual business columns in both directions with `EXCEPT` and binary string comparisons. It also checks duplicate IDs and warehouse timestamps before committing. Existing targets must match or the transaction raises an error; it never silently updates them.

| Loader | Transaction scope | Checks before commit | Additional checks after commit |
| --- | --- | --- | --- |
| Bronze SQL | All initially empty Bronze tables in one transaction | Import errors and CSV-aware supplied counts for loaded tables | Python full typed-row multiset, boundary-record, and skipped-table validation |
| CRM SQL | Customer and product inserts together | Source guards; expected row equality/counts; business IDs; audit timestamps | Ten SQL quality assertions; rerun and Bronze/Silver fingerprints |
| Sales SQL | Sales insert only | Guards, safe arithmetic, reference/chronology checks, exact expected result and count | Fourteen SQL assertions; independent Python oracle; rerun/fingerprints |
| ERP SQL | All three ERP inserts together | Transformed IDs; exact expected rows/counts; audit timestamps; customer gender/date guard | Additional SQL domains/category checks, reported integration gaps, independent Python oracle, rerun/fingerprints |

All SQL loaders use `SET XACT_ABORT ON` and TRY/CATCH rollback. **A failure in a separate post-commit check cannot retroactively roll back the committed load.** No runner automatically clears or repairs a populated table. DDL executes separately from loads. The routines are batch scripts, not stored procedures.

Silver inserts explicitly list the original business columns plus `dwh_create_date`, selecting the transformed temporary rows and `SYSDATETIME()`. DDL retains `DATETIME2 DEFAULT GETDATE()` for compatibility; existing timestamps are not rewritten. Profiling scripts are separate, read-only steps, not automatically run by each loading runner. The preview diagram above describes the development workflow, not an orchestrated pipeline engine.

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
| Validate | **18,484 Silver rows**; unique valid customer IDs; SQL expected-result comparison and separate quality assertions; rerun preserved values and load timestamps |

The exact winner order in `load_crm.sql` is creation date descending, then raw customer key, first name, last name, marital status, and gender descending as `varbinary(100)`. This avoids case-insensitive/padded-string tie ambiguity; completely identical rows yield the same output. Customer key and names are trimmed. S/M marital codes map to Single/Married; F/M genders map to Female/Male; other values become n/a. Retained rows with missing keys/dates or future creation dates stop the loader. All four missing creation dates belong to the excluded NULL-ID rows.

CRM customer/product validation uses SQL staged expected results and independent quality assertions, **not** a separate Python transformation oracle. Python supplies content fingerprints and rerun checks for this phase.

**Count reconciliation:** 18,494 − 4 NULL-ID rows − 6 duplicate excess occurrences = **18,484**.

## 8. Silver CRM product transformation

**Source:** `bronze.crm_prd_info` → **Target:** `silver.crm_prd_info`

| Step | Actual finding or action |
| --- | --- |
| Profile | 397 source product-version records; inspect keys, names, costs, category/line codes, and version dates |
| Transform | Normalize product and category identifiers; standardize product metadata; replace **2 NULL costs with zero** (project cleaning assumption); repair **200 invalid end dates** while retaining history |
| Insert | Keep all 397 product-version records, including historical rows |
| Validate | **397 Silver rows**: **102 closed versions** and **295 current versions**; transformed values verified; rerun stable |

**Important:** A cost of zero may mean “unknown cost” rather than free inventory. Document that assumption. Product history requires validation for temporal gaps, overlaps, and sales occurring before the first known version. The loader trims the raw key, derives the category from its first five characters with hyphen-to-underscore replacement, and takes the product key from position seven. M/R/S/T product lines map to Mountain/Road/Other Sales/Touring; other values become n/a. It rejects ambiguous normalized-key/start-date pairs and cross-category key collisions. `LEAD(prd_start_dt)` partitions by normalized key and orders by start date then prd_id; the prior end becomes next start minus one day, and the latest end is NULL. All 200 changed ends correspond to reversed source ranges. There are no non-midnight starts or negative costs in the current source.

## 9. Silver CRM sales transformation and quality audit

**Source:** `bronze.crm_sales_details` → **Target:** `silver.crm_sales_details`

### A. Profile

60,398 source sales rows. The instructor's checks included invalid dates, order/ship/due chronology, `sales = quantity × price`, NULLs, and nonpositive monetary fields.

### B. Date transformation

Convert the three integer `YYYYMMDD` columns to actual `DATE` values using SQL Server style 112. This **exact order-date expression** from `load_sales.sql` includes the essential length guard; TRY_CONVERT alone may interpret a short token such as 5489 as a year:

```sql
CASE WHEN LEN(CONVERT(varchar(11),sls_order_dt))=8 THEN TRY_CONVERT(date,CONVERT(varchar(11),NULLIF(sls_order_dt,0)),112) END AS sls_order_dt
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

Date comparisons use valid converted values; NULLs do not establish a chronology. The audit defines the 1900–2050 range as 1900-01-01 through 2050-12-31 inclusive, and reports it separately from malformed and invalid-calendar categories. That range is not an automatic load-time exclusion policy.

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

These changes are **traceable to unchanged Bronze rows**, but whether negative amounts represent errors or genuine refunds/returns requires business confirmation. `scripts/silver/transform_crm_sales.sql` was empty during implementation, so the monetary policy is a documented local assumption rather than an existing executable instructor rule.

The exact policy preserves positive quantities and positive unit prices, recomputing sales as their product. If price is NULL/nonpositive, positive sales divided by quantity must give an exact positive integer price. Missing/nonpositive quantities, unresolvable pairs, nonintegral quotients, and INT overflow stop the load. BIGINT intermediates protect arithmetic. No blind ABS(), rounding, or arbitrary zero defaults are used. There are 23 changed sales amounts (8 NULL, 2 zero, 3 negative, 10 other inconsistent) and 12 changed prices (7 NULL, 5 negative). Source known-sales total is 29,355,502; Silver is 29,356,250 (+748).

The local rule assumes gross line sales without an explicit discount/return field. The audit pairs all 35 changes by unique order/product key, but there is no persisted correction-event ledger; the warehouse timestamp is a load timestamp.

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
4. **Join check:** every standardized ERP CID matches CRM **cst_key**, not integer cst_id; unmatched counts are reported in both directions. The old-date threshold is strictly earlier than DATEADD(year,-100,@as_of), evaluated as of 2026-10-19. Those 22 dates are retained. All 16 Silver NULL birthdates originate from future dates; Bronze has zero NULL birthdates.

Illustrative transformation snippets:

```sql
-- Illustrative equivalent of the mapping; @as_of is declared by the full loader.
CASE WHEN LEFT(TRIM(cid),3)='NAS' THEN SUBSTRING(TRIM(cid),4,50)
     ELSE TRIM(cid) END AS cid,
CASE WHEN TRY_CONVERT(date,bdate)>@as_of THEN NULL
     ELSE TRY_CONVERT(date,bdate) END AS bdate,
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
2. **Country standardization:** trim whitespace, map `DE` to Germany and `US`/`USA` to United States, and represent blank/NULL as `n/a`; **4,994** values changed. **The loader supports both D and DE; the actual file uses DE, not the supplied D example.** The 4,994 changes comprise 566 DE, 1,500 US, 2,591 USA, 332 NULL, and 5 whitespace-only values.
3. **Join check:** verify standardized location CIDs match CRM customers.

Illustrative expressions:

```sql
REPLACE(TRIM(cid), '-', '') AS cid,
CASE
    WHEN UPPER(TRIM(cntry)) IN ('D', 'DE') THEN 'Germany'
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
- The supplied rule was to preserve already-clean values; actual local profiling confirmed **0 attribute changes**, 0 NULL/empty attributes, 0 whitespace anomalies, and no conflicting subcategory-to-category mappings.
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

**Verified validation coverage (2026-10-19 snapshot):**
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

The original repository DDL contains DROP/CREATE statements; local scripts deliberately do not execute them. A destructive full-refresh pattern may be useful as a teaching example, but the instructor lesson itself was not independently reviewed for this documentation audit. The verified local implementation is an **insert-if-empty, validate-if-populated load**: matching reruns leave Silver rows and timestamps unchanged; mismatches raise errors without replacement.

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

1. **Maintain the Bronze/Silver milestone:** review each change, keep source data/secrets out of Git, and synchronize upstream without discarding unrelated work.
2. **Gold model design:** define grain and keys for `gold.dim_customers`, `gold.dim_products`, `gold.fact_sales`. Resolve one-to-many/history issues **before** coding.
3. **Preserve fact grain:** ensure **60,398** source sales produce **60,398** Gold fact records, not 18,429 missing or 89,818 duplicated.
4. **Explicit unknown relationships:** unresolved product-version, category, and date cases need documented handling and match-status metrics.
5. **Integration tests:** uniqueness, referential quality, count reconciliation, revenue totals, no temporal overlaps, and deterministic reruns.
6. **Future portfolio work:** architecture diagram, data catalog, business KPI queries, automated checks/CI, and clear local setup instructions for reviewers.

## 17. Reference scripts and reproducibility

Use the actual files for operations, rather than copying illustrative fragments:

| Phase | Profile | Exact DDL/load/runner | Post-load validation and evidence |
| --- | --- | --- | --- |
| Bronze | CSV-aware profiling in Python | [DDL](../scripts/bronze/ddl_bronze.sql), [SQL load](../scripts/bronze/load_bronze.sql), [runner](../scripts/bronze/load_bronze.py) | [Checks](../scripts/bronze/quality_checks.sql), [guide](../scripts/bronze/README.md) |
| CRM customers/products | [Profile](../scripts/silver/profile_crm.sql) | [DDL](../scripts/silver/ddl_crm.sql), [load](../scripts/silver/load_crm.sql), [runner](../scripts/silver/run_crm.py) | [Checks](../scripts/silver/quality_checks.sql), [guide](../scripts/silver/README.md) |
| CRM sales | [Profile](../scripts/silver/profile_sales.sql) | [DDL](../scripts/silver/ddl_sales.sql), [load](../scripts/silver/load_sales.sql), [runner](../scripts/silver/run_sales.py) | [Checks](../scripts/silver/quality_sales.sql), [audit SQL](../scripts/silver/audit_sales.sql), [rules](../scripts/silver/SALES.md), [audit](../scripts/silver/SALES_AUDIT.md) |
| ERP | [Profile](../scripts/silver/profile_erp.sql) | [DDL](../scripts/silver/ddl_erp.sql), [load](../scripts/silver/load_erp.sql), [runner](../scripts/silver/run_erp.py) | [Checks](../scripts/silver/quality_erp.sql), [guide](../scripts/silver/ERP.md) |

For connection, initialization, lifecycle, and execution order, see [LOCAL_SETUP.md](LOCAL_SETUP.md). The Python runner deliberately pins a known image ID, volume name, container name, and mount path. A different Docker image/build or Compose project name requires inspection and an intentional configuration update; bypassing assertions is not a setup method. Run normal Python, not `python -O`, because some checks use assertions. SQL edition checks alone do not prove locality; use the verified Docker runner or documented container command.

**Maintenance rule:** update this guide when an implementation or business assumption changes. Numerical claims should always be rechecked against the runnable quality scripts; descriptive examples should not replace executable source code.
