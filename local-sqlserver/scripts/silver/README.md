# Phase 5: local CRM Silver

> Full-refresh upgrade: [implementation and test results](full_refresh/README.md).
> The legacy scripts described below remain unchanged. Full-refresh timestamps
> renew on success; two approved refreshes and both rollback tests passed.

Run from the repository root:

```bash
python3 local-sqlserver/scripts/silver/run_crm.py
```

Only `silver.crm_cust_info` and `silver.crm_prd_info` are in scope. The runner
uses the existing local Docker connection helper, which verifies container
identity, loopback port 14333, the expected image, the persistent database volume,
and read-only canonical dataset mount. SQL checks DataWarehouse and Developer
Edition. Credentials are never printed or saved. No Azure connection is used.

## Scripts and safety

- `profile_crm.sql`: read-only source profiling used before choosing rules.
- `ddl_crm.sql`: create missing tables only; compare all 17 columns with the
  original Silver names, types, lengths, order, and nullable definitions. Existing
  incompatible tables cause an error rather than being replaced. The original
  DATETIME2 warehouse timestamp with GETDATE() default is retained.
- `load_crm.sql`: set-based CTE transformations staged in session-local temporary
  tables. Both target loads share one transaction with XACT_ABORT and TRY/CATCH.
  Source locks stabilize reconciliation; target exclusive locks serialize the
  empty-table checks. Empty targets receive the expected rows. Populated targets
  are preserved and must match the complete expected result; mismatch stops and
  rolls back any inserts in the other table. No update/reset path is provided.
- `quality_checks.sql`: ten independent checks for required keys/dates, duplicate
  customer IDs and external keys, category domains, trimmed strings, product IDs
  and history keys, valid costs/date ranges, and historical continuity/open ends.
- `run_crm.py`: executes DDL, load, and quality checks, reruns the transformation,
  and verifies content fingerprints including Silver timestamps. Before and after
  fingerprints cover every field and occurrence in all six Bronze tables.

The loader checks complete bidirectional expected/actual row equality and counts
before committing. String comparisons use binary values to detect case and
trailing-space differences. Reruns with unchanged source are no-ops. Changed
source requires an explicitly reviewed future incremental/update strategy;
existing Silver records are never silently refreshed.

## Customer rules and evidence

Actual Bronze: 18,494 rows, 18,484 distinct non-NULL customer IDs. Four records
have NULL IDs and NULL creation dates; exclude those four only. Five repeated-ID
groups contain six excess occurrences: IDs 29449, 29473, 29433, and 29483 appear
twice; 29466 appears three times.

Choose the most recent creation date for each non-NULL ID. Break ties by the raw
customer key, first name, last name, marital status, and gender, descending by
binary value. Identical rows yield identical output regardless of physical row
order. Trim customer key and names. Normalize trimmed, uppercased marital codes
S/M to Single/Married and gender F/M to Female/Male; everything else becomes n/a.

TRY_CONVERT validates date conversion. A retained customer with a missing key,
missing creation date, or future creation date stops the load for review rather
than being silently excluded. The current source has no such retained records.
Creation dates range from 2025-10-06 to 2026-01-27. Null-ID exclusions and duplicate
consolidation are derived from source counts, not a hardcoded target count.

Verified reconciliation: **18,494 - 4 - 6 = 18,484**. No further exclusions.

## Product rules and evidence

Actual Bronze: 397 rows with 397 unique prd_id values, representing 295 historical
product keys. There are two NULL costs, no negative costs, no missing/future start
dates, and no non-midnight starts. All keys satisfy the expected category prefix
layout; normalized keys have no cross-category collisions or same-day histories.

Trim the raw key. Replace the hyphen in its first five characters with an
underscore to form cat_id; take characters seven onward as the product key.
Trim product names. Replace NULL costs with zero. Map trimmed, uppercased product
line M/R/S/T to Mountain/Road/Other Sales/Touring; unknown/NULL becomes n/a.

Preserve all historical versions. prd_id is a unique version identifier;
(prd_key, prd_start_dt) is the historical business key. prd_key alone is expected
to repeat. Convert starts to DATE using TRY_CONVERT. Partition by normalized
product key and order by start date then prd_id. End each version one day before
the next start; leave the final version's end NULL. Malformed keys, ambiguous
histories, category collisions, missing starts, negative costs, and invalid
resulting ranges stop loading rather than silently dropping records.

Exactly **200** source rows have reversed ranges, and exactly **200** end dates
changed. Result: **397 rows**, **102 closed historical versions**, and **295 open
current versions**. No products excluded or merged.

## Intentional differences from earlier scripts

- Original files under `scripts/silver/` are untouched. Local DDL never drops
  tables and creates only these two CRM tables.
- Customer preview ordered only by date; the earlier loader added string tie
  breakers. This implementation compares all tie-break fields as binary values,
  avoiding dependence on case-insensitive/padded SQL string comparison.
- Customer keys and product keys are trimmed before use, in addition to names.
- Product histories partition by normalized key, with collision checks. For the
  current data this produces the same grouping as the earlier raw-key design.
- Existing normalization mappings, NULL-cost-to-zero rule, date types, and
  historical end-date design are retained.
- Source-derived expected counts replace hardcoded 18,484/397 assertions.
- The two loads commit atomically. Matching populated tables are validated and
  preserved on rerun instead of throwing solely because rows exist. Any actual
  mismatch still stops without overwriting rows.
- Inserts explicitly populate dwh_create_date using SYSDATETIME(), preserving
  DATETIME2 precision; the original DDL default remains available. Timestamps are
  never rewritten on reruns.

## Validation results — 2026-10-19

| Dataset | Bronze | Excluded | Duplicate occurrences consolidated | Silver |
|---|---:|---:|---:|---:|
| CRM customers | 18,494 | 4 | 6 | 18,484 |
| CRM product versions | 397 | 0 | 0 | 397 |

All ten quality checks returned zero failures. All 17 column definitions matched
original Silver types and nullability. Full expected-value reconciliation passed.
The rerun preserved every Silver value and timestamp. All six Bronze content
fingerprints remained unchanged (116,294 rows). SQL's NULL-elimination aggregate
warning is expected while counting distinct customer IDs; NULL exclusions are
counted separately and reconciled explicitly. No ERP, sales, or Gold transforms
were performed.

## Subsequent CRM Sales phase

CRM Sales is implemented separately in [SALES.md](SALES.md). Run `run_sales.py`
for its non-destructive load and validation; `run_crm.py` remains scoped to the
customer/product phase. Sales preserves all 60,398 rows, reports 19 unknown order
dates and 18,410 historical product-coverage gaps, and does not modify the two
existing CRM Silver tables.

## Final CRM Sales read-only audit

See [SALES_AUDIT.md](SALES_AUDIT.md) for date validity, chronology, all product/year
history discrepancies, monetary traceability, and Gold recommendations. Rerun
`audit_sales.sql` using the local-only command in that report; it does not load or
change data. ERP has not been started.

## ERP Silver phase 3

The three ERP tables are loaded and validated separately by `run_erp.py`.
See [ERP.md](ERP.md) for transformation counts, complete country/gender domains,
rerun safety, and the unresolved CO_PD/CO_PE category integration warning. The
22 birthdates older than 100 years remain unchanged. No Gold work has started.
