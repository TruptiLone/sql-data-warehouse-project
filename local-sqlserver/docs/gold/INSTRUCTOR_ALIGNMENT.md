# Instructor Gold alignment — compared, previewed, awaiting DDL approval

> **Current deployment status (verified locally):** all three Gold objects are SQL
> views: 18,484 customers, 295 products and 60,398 sales. The approved deployment
> and full validation have completed. Statements below describing “prepared”,
> “absent” or “awaiting approval” record the earlier design/preview stage.
> Silver still runs `silver.refresh_all`; the local `silver.load_silver` revision
> remains undeployed and has only offline checks. No ETL was run for this audit.

Reference inspected: `/Users/truptaditya/Downloads/sql-data-warehouse-project/scripts/gold/ddl_gold.sql`.
The file was treated as reference SQL, not instructions to execute its DROP statements.
No changes were made to the reference, Bronze or Silver. No Gold DDL was executed.
Read-only metadata inspection returned no existing dim_customers, dim_products or
fact_sales objects, and no physical-table naming conflicts.

## Exact comparison

| Area | Instructor | Prepared local implementation |
|---|---|---|
| Deployment | DROP VIEW then CREATE VIEW | CREATE OR ALTER VIEW; no DROP; non-view conflict guards |
| Customer columns | Ten business columns | Same names/order; no ETL metadata |
| Customer key | ROW_NUMBER ordered by cst_id | Same ordering, qualified ci.cst_id |
| Customer joins | CRM LEFT JOIN ERP demographics/location | Same |
| Gender | CRM when not n/a; otherwise ERP COALESCE | Known Male/Female only, trim/case normalization, NULL/blank/n/a fallback |
| Country/marital status | Direct Silver fields | Aligned to direct fields; removed earlier extra normalization |
| Products | Eleven columns, ROW_NUMBER(start date, product number), current only | Exact SELECT retained |
| Product/category join | LEFT JOIN cat_id=id | Same; no CO_PE crosswalk; missing attributes remain NULL |
| Facts | Nine columns, LEFT JOIN both dimensions | Exact SELECT retained; no synthetic sales key or extra flags |
| Quality checks | Not in reference DDL | Separate read-only key, grain, coverage and reconciliation checks |

The enhanced gender rule was requested earlier. For the current validated Silver
snapshot, bidirectional EXCEPT between instructor and local customer results returned
**zero differences**. Future unexpected gender codes require review; the prepared
customer-only quality script detects domain changes. Product/fact SELECT bodies were
copied from the inspected reference, preserving aliases and expressions; they were
not inferred from a lesson summary.

## Actual exact-query preview

| Check | Actual |
|---|---:|
| Customer rows / unique keys / unique IDs / unique numbers | 18,484 each |
| Product rows / unique keys / unique IDs / unique numbers | 295 each |
| Fact rows | 60,398 |
| Unmatched fact customer / product keys | 0 / 0 |
| Fact duplicate order/product-key pairs | 0 |
| Missing CRM customers/current products | 0 / 0 |
| Sales amount / quantity | 29,356,250 / 60,423 |
| Customer known-gender conflicts / ERP enrichments | 57 / 4,554 |
| Unknown genders / NULL birthdates / unknown countries | 15 / 16 / 337 |
| Instructor/local customer row differences | 0 both directions |
| Product category gaps | 7 current products, CO_PE |

All projected fact attributes were reconciled in both directions to Silver by
recovering source customer/product identifiers from the preview dimensions. Source
row counts plus unique business grain guard against hidden duplicate multiplication.
See [exact output](EXACT_VIEW_PREVIEW.txt). Preview used the exact SELECT bodies from
the three proposed view files, replacing view references with session temporary
results; a transaction held shared locks on all six Silver sources. No persistent
object was created, altered or loaded.

## Semantics and limitations

ERP CO_PD is Components / Pedals / No, but seven CRM products use CO_PE. Preserve the
source category_id and NULL category/subcategory/maintenance, not an invented match.
The seven products have no sales in the earlier snapshot; this does not justify
silently repairing the discrepancy. The warning remains unresolved.

Products are current-state (prd_end_dt IS NULL). Historical sales inherit current
attributes; cost is not proven historical COGS. The previous history profile found
18,410 sales before recorded product history and 19 unknown order dates. All sales
remain in the fact; the instructor fact has no temporal-status column. Diagnose
history separately rather than changing the instructor contract.

ROW_NUMBER keys are dynamically calculated, may renumber when customers/products
change, and are not persistent identities. Facts join to the dimension views to
resolve these same keys. Do not persist them as durable external identifiers.
SQL views enforce no PK/FK/unique constraints. All described keys are logical,
validated by separate tests. Gold is virtual and has no ETL loading procedure.

## Prepared execution plan — not executed

1. Review the source definitions and this comparison.
2. After explicit approval, verify local Docker identity and inspect any current
   view definitions. Stop if any of the three names belongs to a physical table or
   other non-view object. The combined script checks all three before any view DDL.
3. Execute `scripts/gold/ddl_gold.sql` from the repository root using local SQLCMD
   error-exit mode. Its includes create/alter customers → products → sales. Never
   execute selected batches that bypass preflight guards. No tables are dropped.
4. Validate created view column names/types, full-row equality with previews,
   source reconciliation, key uniqueness, unmatched references and category warnings.
   The multi-view deployment is ordered but not atomic; if a later definition fails,
   stop and inspect earlier created views before rerunning.

Current checks prove SELECT execution and static view structure; actual CREATE OR
ALTER compilation and post-creation tests remain pending. Preview command:
`python3 local-sqlserver/scripts/gold/preview_views.py` (no DDL execution path).
