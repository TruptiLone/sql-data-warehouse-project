# Gold view data dictionary — instructor-aligned, not yet created

> **Current deployment status (verified locally):** all three Gold objects are SQL
> views: 18,484 customers, 295 products and 60,398 sales. The approved deployment
> and full validation have completed. Statements below describing “prepared”,
> “absent” or “awaiting approval” record the earlier design/preview stage.
> Silver still runs `silver.refresh_all`; the local `silver.load_silver` revision
> remains undeployed and has only offline checks. No ETL was run for this audit.

Gold is a virtual star schema. No physical tables, enforced PK/FK constraints,
persistent surrogate allocation, ETL load procedure, unknown-member rows or load
metadata are part of these definitions. ROW_NUMBER returns BIGINT; keys may renumber
as source populations change. Silver NVARCHAR fields have length 50. Dates and
measures retain Silver DATE/INT types; no decimal or currency conversion is applied.
NULLs are retained except the explicitly documented gender fallback.

## gold.dim_customers

Grain: one CRM customer. Logical key customer_key; unique business identifiers
customer_id and customer_number. Source uniqueness must remain validated.

| Column | Type | Source / meaning |
|---|---|---|
| customer_key | BIGINT | ROW_NUMBER ordered by ci.cst_id |
| customer_id | INT | ci.cst_id |
| customer_number | NVARCHAR(50) | ci.cst_key |
| first_name | NVARCHAR(50) | ci.cst_firstname |
| last_name | NVARCHAR(50) | ci.cst_lastname |
| country | NVARCHAR(50) | la.cntry directly |
| marital_status | NVARCHAR(50) | ci.cst_marital_status directly |
| gender | NVARCHAR(50) | Known normalized CRM gender, else known ERP gen, else n/a |
| birthdate | DATE | ca.bdate; 16 NULL currently |
| create_date | DATE | ci.cst_create_date; registration date, not ETL time |

CRM is master. ERP joins use ci.cst_key=ca.cid and ci.cst_key=la.cid. NULL/blank/n/a
gender is unknown; case/whitespace are normalized for the fallback. Current genders
have 57 conflicts resolved CRM-first, 4,554 ERP enrichments, 15 unknowns. Country n/a
is already in Silver (337 rows); the view does not invent new country normalization.
See [customer notes](CUSTOMER_DIMENSION.md).

## gold.dim_products

Grain: one current CRM product, prd_end_dt IS NULL (295 rows). Logical PK product_key;
product_number and product_id are unique currently. No separate category dimension.

| Column | Type | Source / meaning |
|---|---|---|
| product_key | BIGINT | ROW_NUMBER ordered by pn.prd_start_dt, pn.prd_key |
| product_id | INT | pn.prd_id, selected current version ID |
| product_number | NVARCHAR(50) | pn.prd_key, product business identifier |
| product_name | NVARCHAR(50) | pn.prd_nm |
| category_id | NVARCHAR(50) | pn.cat_id, preserved including CO_PE |
| category | NVARCHAR(50) | pc.cat; NULL when unmatched |
| subcategory | NVARCHAR(50) | pc.subcat; NULL when unmatched |
| maintenance | NVARCHAR(50) | pc.maintenance; NULL when unmatched |
| cost | INT | pn.prd_cost; current cost, not historical sale cost |
| product_line | NVARCHAR(50) | pn.prd_line |
| start_date | DATE | pn.prd_start_dt, current-version effective start |

LEFT JOIN pn.cat_id=pc.id retains seven unmatched CO_PE products. No crosswalk to
CO_PD is applied. Two costs mapped NULL→0 by Silver retain that value; the view does
not establish that the true procurement cost was zero.

## gold.fact_sales

Grain: one source order/product line, 60,398 rows. Logical candidate unique key
(order_number, product_key) for the current data, not order_number alone. No sales_key
column is in the instructor contract. Future repeated product lines within an order
would require revisiting this candidate key rather than deleting legitimate rows.

| Column | Type | Source / meaning |
|---|---|---|
| order_number | NVARCHAR(50) | sd.sls_ord_num; degenerate dimension |
| product_key | BIGINT | pr.product_key via sd.sls_prd_key=pr.product_number |
| customer_key | BIGINT | cu.customer_key via sd.sls_cust_id=cu.customer_id |
| order_date | DATE | sd.sls_order_dt; 19 NULLs retained |
| shipping_date | DATE | sd.sls_ship_dt |
| due_date | DATE | sd.sls_due_dt |
| sales_amount | INT | sd.sls_sales; additive, currency unspecified |
| quantity | INT | sd.sls_quantity; additive |
| price | INT | sd.sls_price; non-additive unit price |

Both dimension lookups are LEFT JOINs. Missing future lookups produce NULL keys,
not dropped facts or fabricated unknown members; report them and review. Current
preview has none. Attribute histories are not resolved by sale date. Use BIGINT or
suitable decimal aggregates to avoid INT overflow as data grows; do not sum prices.

The [optional physical proposal](optional_physical/PROPOSAL.md) is archived and was
never implemented. It is not the active column contract or execution plan.
