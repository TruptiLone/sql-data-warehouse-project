# Local-server readiness review

The prior readiness review used read-only local metadata checks. For this milestone,
origin/main was fetched and matched main (0 ahead/0 behind) before committing.
No database access, ETL, or data changes were performed during commit preparation.

## Remaining 18 SQL files: classification and disposition

Paths below are relative to local-sqlserver/scripts/.

| File | Classification | Disposition |
|---|---|---|
| init_database.sql | Already readable | Existing section headers, GO and guarded statements retained; formatter candidate rejected |
| bronze/ddl_bronze.sql | Already readable | Existing table blocks retained; candidate failed conservative equivalence checks |
| gold/ddl_gold.sql | Already readable | Short SQLCMD include/dependency plan preserved verbatim |
| bronze/load_bronze.sql | SQLCMD-sensitive | Reformatted with substitutions protected; token/variable sequence and T-SQL parsing verified |
| silver/full_refresh/refresh_all.sql | Generated SQL | Unchanged; must change generator/template and source extraction as a coordinated change |
| silver/ddl_crm.sql | Formatting-sensitive generator input | Exact schema regex and source hash dependency; unchanged |
| silver/ddl_sales.sql | Formatting-sensitive generator input | Exact schema regex and source hash dependency; unchanged |
| silver/ddl_erp.sql | Formatting-sensitive generator input | Exact schema regex and source hash dependency; unchanged |
| silver/load_crm.sql | Formatting-sensitive generator input | Exact INSERT/transaction extraction and hash dependency; unchanged |
| silver/load_sales.sql | Formatting-sensitive generator input | Exact INSERT/transaction extraction and hash dependency; unchanged |
| silver/load_erp.sql | Formatting-sensitive generator input | Exact conditional/INSERT extraction and hash dependency; unchanged |
| silver/quality_checks.sql | Formatting-sensitive generator input | Marker extraction and source hash dependency; unchanged |
| silver/quality_sales.sql | Formatting-sensitive generator input | Marker extraction and source hash dependency; unchanged |
| silver/quality_erp.sql | Formatting-sensitive generator input | Marker extraction and source hash dependency; unchanged |
| gold/preview_star.sql | Formatting-sensitive runner input | Python uses exact ` SELECT ROW_NUMBER()` boundary; unchanged |
| gold/quality_customers.sql | SQL fragment/substitution | Rejected formatting candidate produced unsafe variable spacing; restored current-turn original |
| gold/quality_views.sql | SQL fragment | Begins inside a transaction/TRY established by runner; candidate layout rejected |
| silver/profile_sales.sql | Complex SQL/manual review | Automated candidate could not establish safe, readable output; unchanged |

Generator templates were inspected before considering regenerated edits. Formatting
source extraction and dynamic template composition safely would require coordinated
Python/test changes, not just applying a formatter to generated output. No generated
SQL was hand-edited or regenerated in this review. Full formatting remains deferred
for these explicit exceptions rather than risking validated pipeline behavior.

## Validation

Additional Bronze formatting preserves executable token order, variable names,
SQLCMD substitutions, string/comment contents and transaction/rollback boundaries.
Masked substitutions parse with the T-SQL parser. Git no-index comparison uses a
pre-review snapshot rather than HEAD, preserving previous uncommitted work.
Generation consistency, full-refresh structural checks and git diff --check passed.
Original scripts outside local-sqlserver were not edited. Gold definitions and
preview extraction markers remain intact. No database execution tests were run.

## Deployment and documentation accuracy

Fresh local read-only checks confirm dim_customers, dim_products and fact_sales
are VIEW objects, with 18,484 / 295 / 60,398 rows. Fact totals are 29,356,250 sales
amount and 60,423 units. Earlier approved deployment checks proved unchanged
Bronze/Silver full-row fingerprints including timestamps; this review did not repeat
that expensive fingerprint suite or change source data.

The database still has silver.refresh_all, not silver.load_silver. The pending
local naming/logging revision is not deployed and must not be described as runtime
validated. Its predecessor passed two refreshes and two rollback tests. Top-level
status notes now distinguish current deployment from historical preparation text.
Existing historical evidence files remain intact. Some lower sections intentionally
retain historical “not created” wording; the current-status notes explain this.

Seven CO_PE product category gaps, current-product attribution, and dynamic
ROW_NUMBER keys remain known limitations. No additional EDA or diagram work begun.

## Complete intended local-server commit manifest

This list includes modified tracked files and new files, not already committed
unchanged Bronze/Silver setup files. The approved milestone excludes the undeployed full-refresh naming/logging revision.

- `local-sqlserver/README.md`
- `local-sqlserver/docs/IMPLEMENTATION_GUIDE.md`
- `local-sqlserver/docs/READINESS_REVIEW.md`
- `local-sqlserver/docs/gold/CUSTOMER_DIMENSION.md`
- `local-sqlserver/docs/gold/CUSTOMER_VIEW_PREVIEW.txt`
- `local-sqlserver/docs/gold/DATA_DICTIONARY.md`
- `local-sqlserver/docs/gold/EXACT_VIEW_PREVIEW.txt`
- `local-sqlserver/docs/gold/INSTRUCTOR_ALIGNMENT.md`
- `local-sqlserver/docs/gold/LOGICAL_MODEL.md`
- `local-sqlserver/docs/gold/PROFILE_RESULTS.txt`
- `local-sqlserver/docs/gold/STAR_PREVIEW.txt`
- `local-sqlserver/docs/gold/optional_physical/PROPOSAL.md`
- `local-sqlserver/docs/gold/optional_physical/load_customers.sql.txt`
- `local-sqlserver/scripts/bronze/load_bronze.sql`
- `local-sqlserver/scripts/bronze/quality_checks.sql`
- `local-sqlserver/scripts/gold/ddl_gold.sql`
- `local-sqlserver/scripts/gold/preview_star.sql`
- `local-sqlserver/scripts/gold/preview_views.py`
- `local-sqlserver/scripts/gold/profile_model.py`
- `local-sqlserver/scripts/gold/profile_model.sql`
- `local-sqlserver/scripts/gold/quality_customers.sql`
- `local-sqlserver/scripts/gold/quality_views.sql`
- `local-sqlserver/scripts/gold/reference_customers_select.sql`
- `local-sqlserver/scripts/gold/run_customers.py`
- `local-sqlserver/scripts/gold/view_customers.sql`
- `local-sqlserver/scripts/gold/view_products.sql`
- `local-sqlserver/scripts/gold/view_sales.sql`
- `local-sqlserver/scripts/silver/audit_sales.sql`
- `local-sqlserver/scripts/silver/profile_crm.sql`
- `local-sqlserver/scripts/silver/profile_erp.sql`

## Exclusions and remaining attention

- Exclude local-sqlserver/scripts/silver/check.sql: pre-existing personal scratch SQL,
  formatted in the previous pass but not part of the milestone implementation.
- Exclude docs/scripts/placeholder deletion and all untracked scripts outside
  local-sqlserver. They remain untouched.
- .env, raw source datasets, generated .bulk imports and Python caches are ignored;
  no such files are tracked or in this manifest. The credential-pattern scan found
  no private-key/token patterns in candidate contents. Do not use git add -A.
- No new project dependencies were added. Temporary format tools/backups are in /tmp.
- The user excluded the undeployed Silver naming/logging enhancement. All six
  full_refresh enhancement files remain local; the committed refresh_all is preserved.
- Before pushing, fetch origin/main and reconcile any remote movement without force.
- Formatting exceptions remain documented; full formatting uniformity is not claimed.
