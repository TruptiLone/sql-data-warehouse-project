# Gold customer dimension — SQL view prepared for review

> **Current deployment status (verified locally):** all three Gold objects are SQL
> views: 18,484 customers, 295 products and 60,398 sales. The approved deployment
> and full validation have completed. Statements below describing “prepared”,
> “absent” or “awaiting approval” record the earlier design/preview stage.
> Silver still runs `silver.refresh_all`; the local `silver.load_silver` revision
> remains undeployed and has only offline checks. No ETL was run for this audit.

**Not created.** A read-only local Docker DataWarehouse check found
`gold.dim_customers` ABSENT. The exact proposed SELECT was previewed successfully;
no persistent DDL or writes were executed. Product and sales views remain out of scope.
Gold is a virtual star schema: views read Silver directly, with no separate Gold
load procedure, INSERT process, stored load timestamps, or materialized row storage.

## Definition and column mapping

[view_customers.sql](../../scripts/gold/view_customers.sql) contains the prepared
CREATE OR ALTER VIEW. CRM is the master; both ERP sources use LEFT JOIN on
ci.cst_key=ERP.cid. No Silver ETL metadata or extra analytical columns are included.

| View column | SQL type | Source / rule |
|---|---|---|
| customer_key | BIGINT | ROW_NUMBER() OVER (ORDER BY ci.cst_id) |
| customer_id | INT | ci.cst_id |
| customer_number | NVARCHAR(50) | ci.cst_key |
| first_name | NVARCHAR(50) | ci.cst_firstname |
| last_name | NVARCHAR(50) | ci.cst_lastname |
| country | NVARCHAR(50) | la.cntry directly; existing n/a retained |
| marital_status | NVARCHAR(50) | ci.cst_marital_status directly |
| gender | NVARCHAR(50) | Known CRM Male/Female, else known ERP gen, else n/a |
| birthdate | DATE | ca.bdate |
| create_date | DATE | ci.cst_create_date; business registration date |

Gender comparison trims whitespace and ignores case. NULL, blank and n/a are
unknown. Unexpected new codes are flagged by quality checks. CRM takes precedence
in the 57 known conflicts. No source records are repaired or excluded.

customer_key is **dynamically computed, not persistent**. Ordering is deterministic
for the current unique cst_id population, but an insertion/removal/change in earlier
customer IDs may renumber later customers. Do not persist these keys outside a
consistent view-based query or use them as stable external identifiers. customer_id
and customer_number retain source identity. Duplicate master IDs or ERP join keys
would invalidate the grain; a view does not enforce PK/UNIQUE/FK constraints.
No unknown-member row is fabricated. Names and birthdates remain nullable; current
source IDs are complete, but view metadata is not a NOT NULL constraint guarantee.

## Verified source preview

| Check | Actual | Result |
|---|---:|---|
| Integrated customers | 18,484 | PASS |
| Distinct customer IDs / generated keys | 18,484 / 18,484 | PASS |
| Duplicate IDs / keys | 0 / 0 | PASS |
| Missing CRM master customers | 0 | PASS |
| Missing ERP demographic / location matches | 0 / 0 | PASS |
| Conflicting known CRM/ERP genders | 57 | CRM preferred |
| CRM precedence failures | 0 | PASS |
| Missing CRM gender enriched by ERP | 4,554 | Confirmed |
| Remaining unknown genders | 15 | Retained |
| NULL birthdates | 16 | Retained |
| Unknown countries | 337 | Retained |
| Final female / male | 9,128 / 9,341 | Confirmed |

[Saved aggregate output](CUSTOMER_VIEW_PREVIEW.txt) contains no individual customer
PII. Preview holds shared source locks within a transaction for a consistent source
population, materializes only a session temporary result, then validates uniqueness,
coverage and source gender domains. It does not create or alter any persistent object.
Expected counts are compared here with measured results, not substituted into SQL.

## Execution proposal — approval required

1. Reverify local Docker identity and rerun `python3 local-sqlserver/scripts/gold/run_customers.py`.
   This runner is preview-only; `--apply` is no longer supported.
2. After approval, check object type again. Any existing physical table or other
   non-view object must stop deployment; never DROP or replace it. Review any existing
   view definition before altering it. The DDL file includes a non-view conflict guard
   and SQLCMD `:ON ERROR EXIT`; use SQLCMD error-exit mode, not selected GUI batches
   that bypass the guard.
3. Execute only the reviewed view definition on verified local DataWarehouse.
4. Validate the created view's ten-column metadata, counts, duplicate keys, gender
   precedence and coverage, and compare every view row to the preview SELECT in both
   directions. Repeated queries against unchanged Silver should return identical
   values. No Gold ETL load or refresh procedure is needed.

Runtime SELECT preview passed. CREATE OR ALTER VIEW compilation and post-creation
checks remain pending; no claim is made that the view exists yet. Future Silver
changes appear automatically and require recurring quality checks.

## Superseded physical-table proposal

The earlier IDENTITY/INSERT design was never implemented and is retained only as an
[optional future enhancement](optional_physical/PROPOSAL.md). Its SQL is archived as
non-executable documentation (`.sql.txt`), outside the active scripts directory.
Stable persisted keys would require a separately approved architecture change.

Reference comparison is now complete: see [instructor alignment](INSTRUCTOR_ALIGNMENT.md).
Country and marital status match the instructor direct projections; enhanced gender
handling produces zero current-data differences. Product/fact definitions are now
prepared separately, but no Gold DDL has been executed.
