# CRM Sales — local Silver phase 2

Run from the repository root:

```bash
python3 local-sqlserver/scripts/silver/run_sales.py
```

This command targets only Docker `retailflow-sql-local`, accessed inside the
container through loopback TCP, with the verified host mapping 127.0.0.1:14333.
It checks the image, persistent volume, read-only dataset mount, machine identity,
DataWarehouse, and Developer Edition. It never connects to Azure. The existing
Bronze loader helper is imported for connection handling only, not executed.

## Design evidence

The original `scripts/silver/transform_crm_sales.sql` is **empty (zero bytes)**.
There is no pre-existing executable sales monetary rule to claim compatibility
with. Original `ddl_silver.sql` defines the compatible ten columns: order/product
NVARCHAR(50) keys, INT customer/quantity/sales/price, three DATE columns, and
DATETIME2 warehouse timestamp. These definitions, lengths, nullability, and
DATETIME2 scale are preserved. Original scripts are unchanged.

The existing `scripts/test/bronze_quality_checks.sql` uses an eight-digit check,
TRY_CONVERT with style 112, and NULLIF for zero dates. Its 1900–2050 investigation
range is explicitly provisional, not an established exclusion rule. The local
loader does not invent a new date cutoff or infer missing dates from shipment.

## Rules, affected records, and rationale

| Rule | Affected records | Meaning |
|---|---:|---|
| Convert integer YYYYMMDD dates to DATE | 60,398 rows, three date fields each | Require exactly eight digits and use TRY_CONVERT(...,112) |
| Zero order-date sentinel to NULL | 17 | No recoverable order date; retain the sales row |
| Short malformed order dates to NULL | 2 | Values 5489 and 32154 are not eight-digit dates |
| Ship/due dates to NULL | 0 | All source values are valid |
| Trim order/product keys | 0 | Normalize surrounding spaces defensively |
| Rebuild sales from positive quantity × positive price | 23 | 8 NULL, 2 zero, 3 negative, and 10 other inconsistent amounts |
| Derive missing price as sales ÷ quantity | 7 | Positive sales and quantity; exact integral quotient |
| Derive negative price as sales ÷ quantity | 5 | Positive sales and quantity; exact integral quotient; no ABS() |
| Change quantities | 0 | All quantities are positive and present |
| Exclude/deduplicate rows | 0 | Preserve all 60,398 source sales rows |

All five negative prices have positive sales/quantities, and all three negative
sales have positive prices/quantities. Each corrected negative case has 127–2,188
consistent same-product/price peers. There are no negative or zero quantities.
This supports, but cannot prove, treating these as data inconsistencies.

**Explicit business assumption:** the available amount model is gross line sales
= positive quantity × positive unit price, without an explicit discount/return
field. A valid positive unit price takes precedence over an inconsistent amount.
If the price is unusable, a positive amount and exact quotient determine it.
Negative amounts are therefore not treated as confirmed returns. This is a new,
evidence-backed local rule, not an invented claim about the empty original
transformation. Bronze retains every original value for review. If later business
semantics establish returns/discounts, review this policy before any replacement;
the runner will not overwrite existing Silver rows.

No division rounding, arbitrary zero defaults, or absolute-value sign flips are
used. Missing/nonpositive quantities, unresolvable monetary pairs, nonintegral
price derivations, and INT overflow stop loading for review. BIGINT intermediate
arithmetic protects multiplication; stored INT types retain model compatibility.

The eight-digit test is essential: TRY_CONVERT alone can interpret a short token
such as 5489 as a year. Invalid dates remain NULL; they are not fabricated.

## Product/customer reference handling

All 60,398 customer and normalized product keys exist in the existing Silver
customer/product tables. An order can have multiple products; the observed
business key is `(sls_ord_num, sls_prd_key)`, unique across all source rows.

Product keys repeat legitimately across historical versions. Reference checking
uses EXISTS, not a multiplying join or a uniqueness assertion on product key
alone. Historical date matching is reported separately:

| History coverage | Sales rows |
|---|---:|
| Exactly one date-valid product version | 41,969 |
| Order date before first recorded product version | 18,410 |
| Unknown order date, temporal match unavailable | 19 |
| Multiple date-valid versions | 0 |
| Other internal product-history gaps | 0 |

The 18,410 earlier transactions have valid product keys. They are preserved,
flagged as unresolved historical coverage, and not assigned an invented version.
No existing product validity dates are changed. Later dimensional modeling must
choose a documented policy for these rows and the 19 unknown order dates.

## Atomic loading and rerun behavior

`ddl_sales.sql` creates a missing table only, inside a transaction. A conflicting
object or incompatible existing schema stops execution. `load_sales.sql` holds
shared source/reference locks and an exclusive target lock while checking,
transforming, and loading. XACT_ABORT and TRY/CATCH roll back a failing insert.

The expected result is staged in a session-local temporary table with clear CTEs.
Only an empty target is inserted into. A populated target is preserved and must
match the complete expected transformed values and count. A mismatch stops with
an approval-required message; there is no destructive replacement operation.
Existing warehouse timestamps are never rewritten. An unchanged rerun is a no-op.

Before commit, the loader validates exact bidirectional row equality (binary
string comparison), counts, unique order/product keys, non-NULL timestamps,
amounts, date chronology, and key references. Product temporal coverage warnings
are retained separately from missing-key failures.

## Automated validation and files

- `profile_sales.sql`: read-only pre-cleaning profile, anomaly patterns, negative
  value evidence, key coverage, and product-history investigation.
- `ddl_sales.sql`: original-compatible idempotent table definition and metadata checks.
- `load_sales.sql`: guarded, transactional transformation and reconciliation.
- `quality_sales.sql`: 14 quality assertions plus unresolved-warning/repair reports.
- `run_sales.py`: independent Python date/arithmetic oracle compares every row and
  multiplicity; reruns DDL/load and checks unchanged sales values/timestamps.

Content fingerprints before/after cover all six Bronze tables and the existing
customer and product Silver tables, including their warehouse timestamps.
Raw records are held in memory for validation, never saved into these scripts.

## Verified execution — 2026-10-19

| Metric | Bronze/before | Silver/after |
|---|---:|---:|
| Sales rows | 60,398 | 60,398 |
| Missing or inconsistent amount/price rows | 35 | 0 |
| NULL sales amounts | 8 | 0 |
| NULL prices | 7 | 0 |
| Negative sales amounts | 3 | 0 |
| Negative prices | 5 | 0 |
| Zero sales amounts | 2 | 0 |
| Invalid order dates / unknown order dates | 19 invalid integers | 19 NULL dates |
| Duplicate order/product groups | 0 | 0 |
| Missing customer/product keys | 0 | 0 |
| Known sales amount total (NULLs excluded) | 29,355,502 | 29,356,250 |

The aggregate sales change is +748 under the stated monetary assumption; source
NULL amounts are absent from the before total. All 14 SQL assertions returned
zero failures, and an independent Python oracle matched all 60,398 transformed
rows including multiplicities. The metadata check confirmed all ten original
column definitions. A rerun preserved every sales value and warehouse timestamp.
All six Bronze tables and both previously loaded CRM Silver tables retained
identical content fingerprints. No ERP or Gold work was performed.
