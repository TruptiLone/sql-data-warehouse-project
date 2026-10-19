# ERP Silver transformations — 2026-10-19

Run from the repository root:

```bash
python3 local-sqlserver/scripts/silver/run_erp.py
```

The runner verifies local Docker identity, host loopback mapping 127.0.0.1:14333,
expected image and database volume, and the read-only dataset mount. SQL checks
DataWarehouse/Developer Edition. The imported Bronze connection helper does not
execute its loading entrypoint. Credentials are neither printed nor saved.

## Results

| Table | Bronze | Silver | Distinct transformed IDs | Excluded/merged | Result |
|---|---:|---:|---:|---:|---|
| erp_cust_az12 | 18,484 | 18,484 | 18,484 | 0 | PASS; 22 old birthdates retained for review |
| erp_loc_a101 | 18,484 | 18,484 | 18,484 | 0 | PASS |
| erp_px_cat_g1v2 | 37 | 37 | 37 | 0 | PASS transformations; integration warning below |

All 37,005 ERP source rows are preserved in Silver. Null/empty identifiers and
duplicate transformed identifiers: zero in each table. All 12 columns match the
original Silver names, types, lengths, scale, and nullable definitions. Independent
Python full-row multiset comparisons match the set-based T-SQL output exactly.
Rerunning DDL/load preserved every ERP value and warehouse timestamp. Fingerprints
of all 116,294 Bronze rows and all three existing CRM Silver tables stayed equal.

## Customer rules and affected counts

- Trim the customer ID; remove `NAS` only at its beginning when present:
  **11,042 changed IDs**, zero ID whitespace changes.
- Compare the resulting string with CRM **cst_key**, not integer cst_id. All
  **18,484 match**; zero unmatched in either direction.
- Convert dates using TRY_CONVERT. Dates after the database date, **2026-10-19**
  for this run, become NULL: **16 changed birthdates**, 16 resulting NULLs.
- Define the separate old-date warning as birthdate strictly earlier than
  DATEADD(year,-100,as_of_date). **22 records** meet that review threshold;
  dates range from **1916-02-10 to 1926-09-07**. They are retained unchanged.
  This threshold is an audit convention, not a claim that these dates are invalid.
- Trim and uppercase gender for matching. M/Male → Male, F/Female → Female,
  otherwise n/a. **1,485 gender values change**: 4 M codes, 5 F codes, 1,472 NULLs,
  and 4 whitespace-only values. The profile found 6 values with excess whitespace;
  this count overlaps the gender-normalization counts.

| Standardized gender | Rows |
|---|---:|
| Female | 8,396 |
| Male | 8,612 |
| n/a | 1,476 |

## Location rules and affected counts

Trim identifiers and remove hyphens: **18,484 changed IDs**. All resulting IDs
match CRM cst_key, with zero unmatched in either direction. Trim country strings,
map D/DE to Germany, US/USA to United States, and NULL/empty to n/a. Other country
names retain their trimmed spelling.

The requested D mapping is implemented, but the actual source contains **DE**,
not D. Explicitly including DE is the sole additional country alias; it avoids
leaving German customers split across DE and Germany.

**4,994 country values change:** 566 DE, 1,500 US, 2,591 USA, 332 NULL, and 5
whitespace-only values. Five source countries require whitespace trimming.

| Standardized country | Rows |
|---|---:|
| Australia | 3,591 |
| Canada | 1,571 |
| France | 1,810 |
| Germany | 1,780 |
| United Kingdom | 1,913 |
| United States | 7,482 |
| n/a | 337 |

## Product category rules and integration warning

All **37 IDs** and category/subcategory/maintenance values are copied unchanged:
**zero changed fields**, zero NULL/empty fields, zero whitespace anomalies,
37 distinct IDs and 37 distinct subcategories. No subcategory belongs to conflicting
categories; category prefixes also map consistently to one category.

| Category | Rows |
|---|---:|
| Accessories | 12 |
| Bikes | 3 |
| Clothing | 8 |
| Components | 14 |

Maintenance is already consistent: **Yes 20**, **No 17**.

One unmatched identifier exists in each direction:

- ERP **CO_PD**, Components / Pedals, has no matching CRM category.
- CRM **CO_PE** is absent from ERP and is referenced by **7 product versions / 7
  distinct product keys**.

This resembles a category code mismatch, but similarity does not establish the
correct mapping. Preserve both sources. Confirm a mapping with the source owner
before changing any key. A future Gold join must not silently exclude these
products; report unresolved category attribution. No mapping, CRM update, ERP
exclusion, or Gold implementation was performed.

## Files and safe reruns

- `profile_erp.sql`: read-only source/date/whitespace/domain/integration profile.
- `ddl_erp.sql`: creates missing ERP tables only and validates original metadata.
- `load_erp.sql`: one transaction for all three loads, XACT_ABORT and TRY/CATCH,
  source/reference locks, and exclusive target locks for the empty-table check.
- `quality_erp.sql`: count/key/timestamp assertions, date and normalized-domain
  checks, category consistency checks, and integration/old-date warning reports.
- `run_erp.py`: independent expected transformations, full-row comparisons,
  rerun checks, and protected-table fingerprints.

Existing populated targets are never cleared or refreshed. The loader validates
exact expected values/counts (binary string comparisons) and preserves matching
tables. Any difference stops and rolls back new inserts in this transaction;
review is required before a separate replacement/update strategy. All source
rows remain present, including unmatched categories. Integration warnings are
reported rather than used to filter rows.

Birthdate logic uses the run's database date. If source or date-dependent expected
results change later, a populated-table mismatch will stop instead of silently
rewriting existing records. Original nullable schemas and DATETIME2 timestamps
are preserved; inserts explicitly populate SYSDATETIME() without changing old
load timestamps. No DROP/TRUNCATE/DELETE or original-script modifications occur.

Original repository DDL and category inspection queries were reviewed; no original
ERP loader was found. Local transformations implement the supplied rules and the
explicit DE extension. No secrets or datasets were added to tracked files. No
Azure or Gold work was performed.
