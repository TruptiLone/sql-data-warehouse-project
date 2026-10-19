# Transactional Silver full refresh

**Status: implemented, deployed, and acceptance-tested on 2026-10-19 after explicit
user approval.** Two populated-Silver refreshes committed successfully and both
controlled failure tests restored all six tables exactly. Bronze fingerprints
remained unchanged. No Gold or incremental loading is included.

## Files and operation

- `build.py`: deterministic composer of the preserved local loaders, quality SQL,
  and DDL contract. `--check` detects stale generated output before deployment.
- `refresh_all.sql`: generated `silver.refresh_all` procedure, with source SHA-256
  references in its header. Deployment creates/alters this procedure only.
- `run.py`: verified local Docker orchestration; defaults to preview. Refresh/test
  modes require an explicit confirmation flag and a matching SQL confirmation.
- `test_preapproval.sql`: confirms the missing-approval gate and tests rollback
  using a disposable local temporary table; it does not clear populated Silver.

Run from the repository root with normal Python 3 (not `-O`):

```bash
# Generate/review without connecting to SQL Server.
python3 local-sqlserver/scripts/silver/full_refresh/build.py
python3 local-sqlserver/scripts/silver/full_refresh/build.py --check

# Safe default: deploy procedure and preview against current populated Silver.
python3 local-sqlserver/scripts/silver/full_refresh/run.py preview
```

The preview performs transactional source/target locking, computes expected rows
in temporary tables, and validates existing Silver against them. It does not
execute any Silver TRUNCATE/INSERT. It expects the existing populated tables to
match the source; changed-source differences can make a preview fail. This is
not an arbitrary-source simulation. It can briefly block other database sessions.

**Only after the user confirms populated-table TRUNCATE:**

```bash
# One actual refresh, with every SQL gate before commit.
python3 local-sqlserver/scripts/silver/full_refresh/run.py refresh --confirm-local-silver-refresh

# Acceptance suite: two committed refreshes followed by two deliberately failed
# refreshes that must each restore all six Silver tables and their timestamps.
python3 local-sqlserver/scripts/silver/full_refresh/run.py test --confirm-local-silver-refresh
```

The flag is an explicit operator acknowledgement, not an access-control boundary.
Do not pass it before approval. The runner verifies the known container, loopback
port mapping 127.0.0.1:14333, image, persistent volume, dataset mount and SQL machine
identity. SQL additionally requires DataWarehouse, Developer Edition, loopback
TCP and the expected machine supplied by that verified runner. Do not substitute
an Azure endpoint or run the procedure against a different instance.

## Transaction and dependency order

1. Reject caller-owned transactions, wrong environment, invalid mode, or missing
   confirmation. The procedure owns exactly one transaction.
2. Begin the transaction; acquire an exclusive transaction-owned application lock
   (`RetailFlow360.Silver.FullRefresh`, 10-second acquisition timeout).
3. Require all twelve existing Bronze/Silver tables and the reviewed **39-column
   Silver schema**. Reject incoming foreign keys (including disabled ones), enabled
   target triggers, temporal/replicated/CDC/memory-optimized targets, and indexed
   view dependencies. No constraints, triggers, or views are disabled or dropped.
4. Hold shared Bronze locks to stabilize all source rows and exclusive Silver locks
   throughout refresh/validation. Normal readers/writers may block; schedule an
   appropriate maintenance window. Do not use NOLOCK for consistent reporting.
5. When explicitly enabled, truncate **only** these six Silver tables, in this order:
   sales, ERP customers, ERP locations, ERP categories, CRM products, CRM customers.
6. Reuse the existing CRM customer/product transformations and insert those tables;
   then CRM sales; then ERP customers, locations, and categories. Sales needs CRM
   customer/product keys; ERP integration checks also need the CRM targets.
7. Execute the former post-commit SQL quality scripts **inside this transaction**,
   plus full-refresh row-count, CRM/ERP coverage, country-domain, and timestamp gates.
8. Commit once, only after every critical gate passes. Emit run ID, load timestamp,
   mode, and final COMMITTED status. Intermediate messages are not commit evidence.
9. On error, roll back if a transaction remains, emit structured error details and
   run ID, then THROW the original error so SQLCMD/Python receives failure.

SQL Server will not allow truncating a referenced parent simply because its child
was emptied first. If foreign keys are introduced later, this implementation
stops before truncation; a new reviewed strategy is required. No implicit DELETE
fallback exists. Unexpected engine-level TRUNCATE failures are also caught and
rolled back, including any earlier truncations in the transaction.

## Transformations, timestamps, and validation

The existing `load_crm.sql`, `load_sales.sql`, `load_erp.sql`, DDL, and quality files
remain byte-for-byte unchanged. The builder removes their separate transaction
wrappers, renames one local variable to avoid collision, changes their insert
predicates to the explicit refresh flag, and freezes time expressions to one
`@load_time`. It embeds the unchanged cleaning expressions and expected-result
comparisons. Generated source hashes make these dependencies reviewable; changes
to legacy rules require regeneration and review, not manual generated-SQL edits.

Each successful full refresh **replaces every Silver load timestamp** with the
same DATETIME2 value for that run. Business values are expected to remain equal
for unchanged sources. This intentionally differs from the preserved legacy
insert-if-empty scripts, whose reruns retain timestamps. Failed refreshes restore
both the prior business values and their prior timestamps.

| Table | Required Silver rows |
|---|---:|
| crm_cust_info | 18,484 |
| crm_prd_info | 397 |
| crm_sales_details | 60,398 |
| erp_cust_az12 | 18,484 |
| erp_loc_a101 | 18,484 |
| erp_px_cat_g1v2 | 37 |
| Total | 116,284 |

These fixed counts are the current reviewed snapshot contract, in addition to
source-derived reconciliation. New datasets with different expected counts
require an intentional contract update. Customer NULL-ID exclusion and duplicate
resolution remain unchanged; all other source rows remain represented.

Critical SQL validation covers complete binary-aware expected/actual row equality,
source and snapshot counts, unique/non-NULL business IDs, warehouse timestamps,
product historical continuity, customer/product references, valid dates and
chronology, positive sales/quantity/price and arithmetic, standardized genders,
trimmed strings, and ERP consistency. The current seven standardized countries
(Australia, Canada, France, Germany, United Kingdom, United States, n/a) are an
explicit reviewed domain gate; a newly introduced country requires review.
CRM/ERP customer and location coverage is now a critical pre-commit check in both
directions, rather than only a reported post-load metric.

Known anomalies are **reported, not automatically repaired or treated as failures**:

- 19 unknown sales order dates.
- 18,410 sales before the first recorded product version (41,969 date-valid matches).
- ERP CO_PD versus CRM CO_PE, affecting seven CRM product versions.
- 22 retained birthdates over 100 years old (as of 2026-10-19).

Monetary assumptions (23 amount repairs, 12 price repairs), NULL product cost → 0,
product history rebuilding, prefix/hyphen rules, and D/DE country mapping are
unchanged. Date-dependent rules are evaluated consistently at the run timestamp.
No unsupported historical/category mapping is invented.

## Acceptance and rollback tests

Completed before approval:

- Procedure successfully compiled/deployed on the verified local SQL Server.
- Preview passed all expected-value/count and quality gates on populated tables.
- All twelve Bronze/Silver content fingerprints remained unchanged after preview.
- Calling refresh without confirmation was rejected with error 51303 before writes.
- A disposable `#rollback_probe` TRUNCATE/INSERT followed by error restored its
  exact original rows and timestamps. This proves engine semantics only.

Completed after explicit user approval with `run.py test --confirm-local-silver-refresh`
(exit code 0):

1. **PASS:** Two refreshes committed; complete business-value fingerprints matched
   the starting snapshot. SQL count/duplicate gates passed, and timestamps changed
   on every table after the second successful run.
2. **PASS:** Error **51390 immediately after all six truncations** rolled back;
   every Silver value and timestamp matched the last successful snapshot.
3. **PASS:** An incorrect ERP category count expectation after all inserts and
   quality checks triggered the **real critical row-count gate**, error **51391**.
   All six Silver tables again matched their exact pre-failure snapshot.
4. **PASS:** Complete fingerprints confirmed all 116,294 Bronze rows unchanged.

Committed run evidence (SQL Server clock):

| Run | Run ID | Shared Silver load timestamp | Result |
|---|---|---|---|
| First | `5B0A6852-9270-401F-8609-5B040F46F7FF` | `2026-10-19 21:41:58.1193880` | COMMITTED |
| Second | `8947B152-774A-41CC-A95B-4F84AC016F52` | `2026-10-19 21:42:29.3456374` | COMMITTED |

Final Silver counts: CRM customers 18,484; products 397; sales 60,398;
ERP customers 18,484; locations 18,484; categories 37 (116,284 total).
All 10 CRM and 14 sales assertions and ERP checks passed. Known warnings remained:
19 unknown order dates, 18,410 sales before product history, 22 old birthdates,
and CO_PD/CO_PE affecting 7 CRM products. Both failed attempts preserved the
second successful run's timestamps. SQL aggregate NULL-elimination warnings were
informational; the suite exited successfully.

The test must run without unrelated writers, since fingerprints cover the whole
validation interval. Failure injection modifies only a local table variable for
the expected count; it does not corrupt Bronze or persisted rows. It is disabled
unless an explicitly confirmed refresh specifies a supported failure mode.

External Python fingerprints provide additional evidence; SQL checks are the
commit gates. A client disconnect after COMMIT can make client status uncertain;
inspect final run output and table timestamps before assuming success/failure.
There is no persistent audit-log table, CDC, automatic retry, or incremental mode.
Execution privileges should remain limited to the intended local operator.
