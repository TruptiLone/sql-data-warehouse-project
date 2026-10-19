# OPTIONAL FUTURE DESIGN — SUPERSEDED, NEVER IMPLEMENTED

This archived physical-table proposal is not the active view architecture.
Do not execute its old commands. SQL is retained in [load_customers.sql.txt](load_customers.sql.txt)
for design history only.

# Gold customer dimension — prepared, awaiting execution approval

Only gold.dim_customers is in scope. SQL has been reviewed and its source-only
preview executed against verified local Docker DataWarehouse. No Gold table was
created or loaded. Existing Bronze/Silver rows and pending Silver procedure changes
were not modified. Product dimensions and facts remain proposals.

## Model and source mapping

One row per silver.crm_cust_info.cst_id. Persistent physical table with BIGINT
IDENTITY(1,1) customer_key primary key, unique source_customer_id and customer_number.
Identity values are assigned once; gaps and allocation order carry no meaning.
No ROW_NUMBER regeneration, TRUNCATE, DELETE, MERGE, or UPDATE is used. Matching
reruns leave every key and gold_loaded_at unchanged. Changed source data or a
partially populated destination raises an error instead of silently replacing it.
Future incremental/type-1 update policy is outside this implementation.

There are exactly 18,484 real customers. The previously proposed unknown member is
**deferred**, so no extra row 0 is created; future fact lookup policy must be reviewed
before adding one. Both source identifiers are NOT NULL in this implementation.

| Target | Source / rule |
|---|---|
| customer_key | BIGINT IDENTITY; stable persisted primary key |
| source_customer_id | CRM cst_id, INT NOT NULL UNIQUE |
| customer_number | CRM cst_key, NVARCHAR(50) NOT NULL UNIQUE |
| first_name / last_name | CRM cst_firstname / cst_lastname, NVARCHAR(50) NULL |
| marital_status | CRM cst_marital_status trimmed; NULL/blank → n/a |
| gender | Known CRM Male/Female; otherwise known ERP gen; otherwise n/a |
| gender_source | CRM / ERP / UNKNOWN |
| gender_conflict | BIT: both known and disagree; retain CRM value |
| birth_date | ERP bdate, DATE NULL; no new date cleaning |
| country | ERP cntry trimmed; NULL/blank → n/a |
| customer_registration_date | CRM cst_create_date, DATE NULL |
| gold_loaded_at | DATETIME2(7), one initial-load timestamp, preserved on rerun |

All descriptive fields other than names are NVARCHAR(50) NOT NULL; gender_conflict
is BIT NOT NULL. Birthdate and registration date remain nullable. Gender matching
trims whitespace and normalizes case; NULL, blank and n/a all mean unknown.
Unexpected nonempty gender codes fail validation rather than disappearing as unknown.
CRM precedence is the user-approved Gold rule; it does not establish which source
is objectively correct for the 57 disagreements. No Silver values are changed.

The executable integration is in [load_customers.sql](load_customers.sql.txt).
It uses a CRM-driven LEFT JOIN on cst_key=ERP cid for both demographic and location
sources, followed by normalized CRM/ERP gender expressions and COALESCE precedence.
Uniqueness and bidirectional coverage are checked before the joins, preventing fanout
and exposing missing integration partners. No customer PII samples are written to logs.

## Preview evidence

| Validation | Result |
|---|---:|
| Integrated customers | 18,484 |
| Known CRM/ERP gender conflicts | 57 |
| Missing CRM gender filled from ERP | 4,554 |
| ERP female / male enrichments | 2,280 / 2,274 |
| Retained known CRM female / male | 6,848 / 7,067 |
| Remaining unknown gender | 15 |
| Final female / male | 9,128 / 9,341 |
| NULL birthdates retained | 16 |
| Unknown country (n/a) retained | 337 |
| Missing first / last names | 0 / 0 |
| NULL registration dates | 0 |
| Duplicate/NULL/blank source integration keys | 0 |
| Missing or orphan ERP integration keys | 0 |

Conflict details remain accessible in Silver; the Gold conflict flag will make all
57 queryable without copying names or demographic records into documentation.
Do not treat retained unknown countries, birthdates or genders as failed integration.

## Transaction, reruns and checks

One transaction locks the three Silver sources for a consistent integration and
serializes customer-dimension operations using an application lock. Preview builds
only a session temporary expected-result table, reports aggregate quality, commits
and returns **before any Gold DDL/DML**. Locks may briefly block concurrent refreshes.

Apply creates the table only if absent. An existing non-table target, schema mismatch
or enabled target trigger stops the operation. Existing populated data is never
modified. An empty target is inserted once, then checked against the complete expected
result using binary string comparisons in both directions, row counts and uniqueness.
Errors roll back table creation/inserts and rethrow with number/message/state/line.
Success is reported only after COMMIT. Source count is deliberately pinned at 18,484;
a changed dataset requires contract review. Existing schema checks are defensive,
not permission to adopt an arbitrary manually created table without review.

Commands from repository root:

```bash
# Source-only preview; already executed successfully.
python3 local-sqlserver/scripts/gold/run_customers.py

# ONLY after execution approval: create/load and validate the dimension.
python3 local-sqlserver/scripts/gold/run_customers.py --apply
```

Pending tests after approval: apply successfully; verify 18,484 unique source IDs,
customer numbers and positive surrogate keys; confirm all values equal the expected
integration; capture target rows/keys/timestamps, rerun and compare them exactly;
verify Bronze/Silver fingerprints unchanged. Current preview verifies source SQL and
integration, not runtime execution of the unexecuted CREATE/INSERT branch or target
rerun stability. No claim is made that Gold has already been loaded.
