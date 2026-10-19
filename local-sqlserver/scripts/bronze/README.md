# Local Bronze loading

Run from the repository root:

```bash
python3 local-sqlserver/scripts/bronze/load_bronze.py
```

The runner requires Python 3 and Docker. It verifies the loopback port mapping,
container machine identity, pinned expected image ID, existing database volume,
and read-only canonical dataset mount. SQL additionally checks DataWarehouse and
Developer Edition. Passwords stay inside the container environment.

Compose mounts `local-sqlserver/datasets/` read-only at
`/var/opt/retailflow-datasets`. Applying this mount recreates the container but
retains `local-sqlserver_retailflow_sql_fresh` at `/var/opt/mssql`. Do not remove
that volume. Duplicate source files elsewhere in the repository are untouched.

The CSV-aware parser reads UTF-8 (with optional BOM), comma delimiters, and
standard double-quote quoting, validates header order against the original DDL,
and counts logical records rather than newline characters. All current sources
use CRLF and contain no quote characters. Customer CRM, customer ERP, and ERP
category files have no final newline.

The runner writes ignored, derived files under `datasets/.bulk/` using UTF-16
with a BOM, LF separators, and a final newline. It parses each derived file back
and verifies exact field equality. Original files are never rewritten. This
avoids lost final records and preserves Unicode on Linux SQL Server, where the
CODEPAGE bulk-import option is unsupported. Generated manifest counts are local
and ignored; no raw values are embedded in committed scripts.

`load_bronze.sql` uses SQL Server CSV parsing with widechar input, explicit LF
termination, KEEPNULLS, and zero tolerated import errors. One transaction covers
all initially empty tables; errors or count mismatches roll back those loads.
Exclusive table locks protect the empty-table check. Populated tables are skipped
and reported, then still validated against the source. Never clear a populated
table merely to rerun this loader.

After loading, the runner retrieves rows as JSON in memory and compares complete
row multisets (values and duplicate multiplicities) with the typed source rows.
It also verifies first and last source records; SQL tables have no physical row
order. Empty fields become NULL and values follow the original INT/DATE/DATETIME
DDL semantics. Strings retain whitespace, Unicode, and original categories.
Counts, identifier anomalies, and full-row duplicates are reported without raw
record output. `quality_checks.sql` adds read-only sales identifier and composite
order/product checks.

## Verified load: 2026-10-19

| Table | Source records | Loaded records | Validation |
|---|---:|---:|---|
| crm_cust_info | 18,494 | 18,494 | Exact row multiset and boundary records match |
| crm_prd_info | 397 | 397 | Exact row multiset and boundary records match |
| crm_sales_details | 60,398 | 60,398 | Exact row multiset and boundary records match |
| erp_cust_az12 | 18,484 | 18,484 | Exact row multiset and boundary records match |
| erp_loc_a101 | 18,484 | 18,484 | Exact row multiset and boundary records match |
| erp_px_cat_g1v2 | 37 | 37 | Exact row multiset and boundary records match |

Total: 116,294 rows. No full-row duplicates or source/table discrepancies.
CRM customers retain four NULL IDs and five repeated non-NULL ID groups (six
excess occurrences). All other primary identifier checks found no NULL values.
Sales contains 17,991 repeated order-number groups; order numbers are not unique
line identifiers. Sales has zero NULL order/product/customer identifiers and zero
repeated order/product pairs. A rerun skipped all six populated tables and again
passed the full source comparison. These source characteristics are preserved for later Silver
work, not cleaned during ingestion.

The initial sqlcmd display-option and unsupported CODEPAGE attempts failed before
importing records. The corrected Unicode load completed without import errors.
