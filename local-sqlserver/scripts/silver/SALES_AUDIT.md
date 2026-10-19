# Final CRM Sales quality audit — 2026-10-19

Read-only audit of local Docker DataWarehouse. No database/table/row changes.
Before/after full-content fingerprints were identical for all six Bronze and all
three CRM Silver tables. Bronze and Silver sales each contain 60,398 rows.

## Rerun

From the repository root, against the already verified local container:

```bash
docker exec -i retailflow-sql-local sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -S tcp:127.0.0.1,1433 -U sa -C -b -l 15 -d DataWarehouse -y 0 -w 65535' < local-sqlserver/scripts/silver/audit_sales.sql
```

The SQL guards database/edition and returns named JSON result sections. It uses
only reads and session settings: no DDL/DML or temporary objects. Do not run a
load script to rerun this audit. The SQL includes complete product/year grouping
and all 35 original/corrected monetary pairs, not merely the samples below.

## Dates

Source integer dates must be positive and exactly eight digits before
TRY_CONVERT(DATE, CONVERT(varchar(11), value), 112). Otherwise tokens such as 5489
can be misinterpreted as a year. Categories below are mutually exclusive.
The requested range means **1900-01-01 through 2050-12-31, inclusive**.

| Field | Source NULL | Zero | Malformed | Invalid eight-digit calendar date | Valid but outside range | Valid in range | Silver NULL |
|---|---:|---:|---:|---:|---:|---:|---:|
| Order | 0 | 17 | 2 | 0 | 0 | 60,379 | 19 |
| Shipping | 0 | 0 | 0 | 0 | 0 | 60,398 | 0 |
| Due | 0 | 0 | 0 | 0 | 0 | 60,398 | 0 |

All three source-to-Silver date comparisons returned zero mismatches across
60,398 rows per field. Valid order dates range from 2010-12-29 to 2014-01-28;
shipping from 2011-01-05 to 2014-02-04; due from 2011-01-10 to 2014-02-09.
There are 19 unusable source order dates in total; zero invalid-calendar counts
do not mean every source date is valid.

| Sample order / product | Source order date | Silver date |
|---|---:|---|
| SO64338 / HL-U509-B | 0 | NULL |
| SO69215 / TT-M928 | 5489 | NULL |
| SO69215 / TI-M823 | 32154 | NULL |

Order later than shipping: **0**. Order later than due: **0**. Either violation:
**0**. Same-day order/shipping: **0**. Same-day order/due: **0**. All three dates
on the same day: **0**. The 19 NULL order dates are not comparable; they are not
counted as successful chronological comparisons or same-day orders.

## Product-history discrepancies

**18,410 sales rows**, covering **119 products** and **10,677 distinct orders**,
predate their product's earliest recorded version by **1–185 days**. These are
valid existing product keys, not missing product references. Their sales dates
range from 2010-12-29 to 2013-06-30 and their Silver sales amount totals 8,649,691.
There are **181 product/year groups**, enumerated in the appendix.

| Sales year | Affected rows | Distinct products in year | Sales amount |
|---|---:|---:|---:|
| 2010 | 14 | 10 | 43,419 |
| 2011 | 1,020 | 37 | 3,267,263 |
| 2012 | 1,333 | 59 | 2,530,526 |
| 2013 | 16,043 | 75 | 2,808,483 |

Distinct product counts overlap across years. The largest product/year group is
WB-H098 in 2013: 1,737 sales from January through June, preceding its first
recorded version dated 2013-07-01. PK-7098 has 1,357 such 2013 sales and TT-M928
has 1,316. For example, SO46676 / BK-R64Y-42 was ordered on 2011-12-29, 185 days
before the first recorded version on 2012-07-01.

This pattern is consistent with incomplete or differently effective-dated product
history; the dataset alone cannot establish the true reason. It does not justify
changing transaction dates or backdating product versions automatically.

### Measured join impact

- Joining sales to every product version using product key alone produces
  **89,818 rows**, an extra **29,420**, risking duplicated facts and inflated sums.
- An inner join on product key AND order date within version start/end produces
  **41,969 rows**. It loses **18,429 rows**: 18,410 before-first-version sales plus
  19 unknown-order-date sales, totaling **8,654,683** in Silver sales amount.
- There are **0** missing product keys and **0** multiple date-valid matches.

### Recommended Gold approach — recommendation only

Preserve one fact per original order/product pair using a LEFT temporal lookup.
Use the known version only for the 41,969 unambiguous date matches. For the
remaining 18,429 facts, use an explicit unresolved/unknown version surrogate and
retain the original product business key, order date, and a match-status field
(`before_first_version` or `unknown_order_date`). Keep an independent stable
product identity where product-level grouping is needed without claiming that
historical attributes are known.

Do not filter unmatched facts, join all product versions, silently substitute the
current/first version, or backdate Silver history. Request earlier product history
or a documented business-approved fallback before assigning historical attributes.
If a current-product reporting view is later desired, label it as current-state
attribution rather than an as-of historical join.

Gold acceptance checks should preserve 60,398 fact rows, uniqueness of the
order/product grain, and the Silver sales total of 29,356,250. Report matching
status counts and require at most one historical version per fact. No Gold
objects were created during this audit.

## Monetary correction traceability

All **60,398** source/target sales pairs join uniquely by trimmed order/product
key. All **35** corrected rows retain their original Bronze quantities, prices,
and amounts alongside the corrected Silver values. The SQL emits all pairs with
classification and the Silver warehouse timestamp. There are no duplicate keys,
quantity changes, arithmetic mismatches, or untraceable corrections.

| Correction classification | Rows |
|---|---:|
| Missing sales amount | 8 |
| Zero sales amount | 2 |
| Negative sales amount | 3 |
| Other inconsistent positive sales amount | 10 |
| Missing price | 7 |
| Negative price | 5 |
| Total | 35 |

| Sample order / product | Quantity | Original → Silver sales | Original → Silver price |
|---|---:|---|---|
| SO58335 / TI-M823 | 2 | 35 → 70 | 35 → 35 |
| SO61548 / CA-1098 | 1 | NULL → 9 | 9 → 9 |
| SO61570 / CA-1098 | 1 | -18 → 9 | 9 → 9 |
| SO57804 / BK-M38S-40 | 1 | 769 → 769 | -769 → 769 |
| SO51259 / WB-H098 | 2 | 10 → 10 | NULL → 5 |

The negative-sales example is recomputation (1 × 9), not absolute value (18).
Known source sales totals 29,355,502, excluding source NULLs; corrected Silver
sales totals 29,356,250, a difference of +748. Price corrections leave the sales
amount unchanged. The correction policy assumes positive unit prices and
quantities represent gross line sales; the data cannot prove that negative
amounts were not returns or that discrepancies were not discounts. This remains
a business-semantic assumption to confirm before trusted financial reporting.

Traceability is reproducible from preserved Bronze, stable business keys, the
transformation script, and Silver values. There is no dedicated persisted
correction-event ledger or rule-version column; the warehouse timestamp records
loading, not a separate correction event. Before any future mutable reload,
retain a versioned audit extract or formal correction ledger so this evidence is
not lost. No such schema change was made here.

## Outcome

Read-only audit complete. Existing data and warehouse timestamps preserved. The
only unresolved issues are the 19 unknown order dates, the 18,410 historical
coverage gaps, and confirmation of the monetary business assumption. No ERP or
Gold work started.

## Appendix: all product/year discrepancies

| Product key | Sales year | First recorded version | Rows | Days before (min–max) | Sales amount |
|---|---:|---|---:|---|---:|
| BC-M005 | 2012 | 2013-07-01 | 11 | 182–185 | 110 |
| BC-M005 | 2013 | 2013-07-01 | 818 | 1–181 | 8,270 |
| BC-R205 | 2012 | 2013-07-01 | 9 | 182–185 | 81 |
| BC-R205 | 2013 | 2013-07-01 | 704 | 1–181 | 6,336 |
| BK-M18B-40 | 2012 | 2013-07-01 | 1 | 183–183 | 540 |
| BK-M18B-40 | 2013 | 2013-07-01 | 22 | 10–174 | 11,880 |
| BK-M18B-42 | 2013 | 2013-07-01 | 22 | 3–173 | 11,880 |
| BK-M18B-44 | 2013 | 2013-07-01 | 25 | 14–177 | 13,500 |
| BK-M18B-48 | 2013 | 2013-07-01 | 18 | 4–177 | 9,720 |
| BK-M18B-52 | 2013 | 2013-07-01 | 13 | 4–171 | 7,020 |
| BK-M18S-40 | 2013 | 2013-07-01 | 15 | 2–178 | 8,475 |
| BK-M18S-42 | 2013 | 2013-07-01 | 18 | 15–181 | 10,170 |
| BK-M18S-44 | 2012 | 2013-07-01 | 1 | 183–183 | 565 |
| BK-M18S-44 | 2013 | 2013-07-01 | 16 | 9–158 | 9,040 |
| BK-M18S-48 | 2013 | 2013-07-01 | 22 | 1–166 | 12,430 |
| BK-M18S-52 | 2013 | 2013-07-01 | 22 | 9–166 | 12,430 |
| BK-M38S-38 | 2013 | 2013-07-01 | 57 | 4–177 | 43,833 |
| BK-M38S-40 | 2012 | 2013-07-01 | 1 | 184–184 | 769 |
| BK-M38S-40 | 2013 | 2013-07-01 | 49 | 2–180 | 37,681 |
| BK-M38S-42 | 2013 | 2013-07-01 | 48 | 2–175 | 36,912 |
| BK-M38S-46 | 2013 | 2013-07-01 | 52 | 8–174 | 39,988 |
| BK-M68B-38 | 2011 | 2012-07-01 | 2 | 183–185 | 4,098 |
| BK-M68B-38 | 2012 | 2012-07-01 | 50 | 7–180 | 102,450 |
| BK-M68B-42 | 2012 | 2012-07-01 | 78 | 2–181 | 159,822 |
| BK-M68B-46 | 2011 | 2012-07-01 | 1 | 185–185 | 2,049 |
| BK-M68B-46 | 2012 | 2012-07-01 | 79 | 5–180 | 161,871 |
| BK-M68S-38 | 2012 | 2012-07-01 | 67 | 1–182 | 138,757 |
| BK-M68S-42 | 2011 | 2012-07-01 | 1 | 185–185 | 2,071 |
| BK-M68S-42 | 2012 | 2012-07-01 | 65 | 2–179 | 134,615 |
| BK-M68S-46 | 2012 | 2012-07-01 | 50 | 3–181 | 103,550 |
| BK-M82B-38 | 2011 | 2011-07-01 | 21 | 2–157 | 70,875 |
| BK-M82B-42 | 2011 | 2011-07-01 | 18 | 6–156 | 60,750 |
| BK-M82B-44 | 2011 | 2011-07-01 | 29 | 3–176 | 97,875 |
| BK-M82B-48 | 2010 | 2011-07-01 | 1 | 183–183 | 3,375 |
| BK-M82B-48 | 2011 | 2011-07-01 | 20 | 12–163 | 67,500 |
| BK-M82S-38 | 2010 | 2011-07-01 | 1 | 183–183 | 3,400 |
| BK-M82S-38 | 2011 | 2011-07-01 | 28 | 2–163 | 95,200 |
| BK-M82S-42 | 2011 | 2011-07-01 | 17 | 23–165 | 57,800 |
| BK-M82S-44 | 2010 | 2011-07-01 | 3 | 184–184 | 10,200 |
| BK-M82S-44 | 2011 | 2011-07-01 | 22 | 4–176 | 74,800 |
| BK-M82S-48 | 2011 | 2011-07-01 | 13 | 61–173 | 44,200 |
| BK-R19B-44 | 2012 | 2013-07-01 | 3 | 182–184 | 1,620 |
| BK-R19B-44 | 2013 | 2013-07-01 | 149 | 2–179 | 80,460 |
| BK-R19B-48 | 2012 | 2013-07-01 | 2 | 182–183 | 1,080 |
| BK-R19B-48 | 2013 | 2013-07-01 | 158 | 2–178 | 85,320 |
| BK-R19B-52 | 2012 | 2013-07-01 | 4 | 182–185 | 2,160 |
| BK-R19B-52 | 2013 | 2013-07-01 | 148 | 1–178 | 79,920 |
| BK-R19B-58 | 2012 | 2013-07-01 | 2 | 182–183 | 1,080 |
| BK-R19B-58 | 2013 | 2013-07-01 | 140 | 1–175 | 75,600 |
| BK-R50B-44 | 2011 | 2011-07-01 | 12 | 4–157 | 8,388 |
| BK-R50B-48 | 2011 | 2011-07-01 | 2 | 6–97 | 1,398 |
| BK-R50B-52 | 2011 | 2011-07-01 | 17 | 4–162 | 11,883 |
| BK-R50B-58 | 2011 | 2011-07-01 | 10 | 1–178 | 6,990 |
| BK-R50B-60 | 2011 | 2011-07-01 | 10 | 11–149 | 6,990 |
| BK-R50B-62 | 2010 | 2011-07-01 | 1 | 184–184 | 699 |
| BK-R50B-62 | 2011 | 2011-07-01 | 13 | 24–180 | 9,087 |
| BK-R50R-44 | 2011 | 2011-07-01 | 7 | 40–165 | 4,893 |
| BK-R50R-48 | 2011 | 2011-07-01 | 9 | 8–160 | 6,291 |
| BK-R50R-52 | 2010 | 2011-07-01 | 1 | 182–182 | 699 |
| BK-R50R-52 | 2011 | 2011-07-01 | 8 | 13–166 | 5,592 |
| BK-R50R-58 | 2011 | 2011-07-01 | 8 | 21–135 | 5,592 |
| BK-R50R-60 | 2011 | 2011-07-01 | 12 | 4–151 | 8,388 |
| BK-R50R-62 | 2011 | 2011-07-01 | 3 | 17–155 | 2,097 |
| BK-R64Y-38 | 2011 | 2012-07-01 | 1 | 184–184 | 1,000 |
| BK-R64Y-38 | 2012 | 2012-07-01 | 25 | 4–182 | 25,000 |
| BK-R64Y-40 | 2012 | 2012-07-01 | 28 | 1–176 | 28,000 |
| BK-R64Y-42 | 2011 | 2012-07-01 | 1 | 185–185 | 1,000 |
| BK-R64Y-42 | 2012 | 2012-07-01 | 34 | 1–180 | 34,000 |
| BK-R64Y-44 | 2012 | 2012-07-01 | 26 | 4–181 | 26,000 |
| BK-R64Y-48 | 2012 | 2012-07-01 | 33 | 8–145 | 33,000 |
| BK-R79Y-40 | 2012 | 2013-07-01 | 1 | 184–184 | 1,701 |
| BK-R79Y-40 | 2013 | 2013-07-01 | 90 | 1–177 | 153,090 |
| BK-R79Y-42 | 2012 | 2013-07-01 | 3 | 182–185 | 5,103 |
| BK-R79Y-42 | 2013 | 2013-07-01 | 78 | 3–179 | 132,678 |
| BK-R79Y-44 | 2013 | 2013-07-01 | 71 | 1–179 | 120,771 |
| BK-R79Y-48 | 2012 | 2013-07-01 | 1 | 182–182 | 1,701 |
| BK-R79Y-48 | 2013 | 2013-07-01 | 78 | 1–174 | 132,678 |
| BK-R89B-44 | 2011 | 2012-07-01 | 3 | 183–185 | 6,546 |
| BK-R89B-44 | 2012 | 2012-07-01 | 63 | 4–181 | 137,466 |
| BK-R89B-48 | 2012 | 2012-07-01 | 87 | 1–182 | 189,834 |
| BK-R89B-52 | 2011 | 2012-07-01 | 2 | 183–184 | 4,364 |
| BK-R89B-52 | 2012 | 2012-07-01 | 106 | 2–182 | 231,292 |
| BK-R89B-58 | 2011 | 2012-07-01 | 1 | 183–183 | 2,182 |
| BK-R89B-58 | 2012 | 2012-07-01 | 78 | 6–179 | 170,196 |
| BK-R89R-44 | 2011 | 2012-07-01 | 2 | 183–183 | 4,886 |
| BK-R89R-44 | 2012 | 2012-07-01 | 70 | 3–181 | 171,010 |
| BK-R89R-48 | 2011 | 2012-07-01 | 3 | 183–183 | 7,329 |
| BK-R89R-48 | 2012 | 2012-07-01 | 88 | 1–182 | 214,984 |
| BK-R89R-52 | 2011 | 2012-07-01 | 1 | 183–183 | 2,443 |
| BK-R89R-52 | 2012 | 2012-07-01 | 82 | 5–182 | 200,326 |
| BK-R89R-58 | 2011 | 2012-07-01 | 3 | 183–185 | 6,546 |
| BK-R89R-58 | 2012 | 2012-07-01 | 105 | 3–181 | 229,110 |
| BK-R93R-44 | 2010 | 2011-07-01 | 1 | 183–183 | 3,578 |
| BK-R93R-44 | 2011 | 2011-07-01 | 139 | 1–181 | 497,342 |
| BK-R93R-48 | 2010 | 2011-07-01 | 2 | 182–182 | 7,156 |
| BK-R93R-48 | 2011 | 2011-07-01 | 151 | 1–179 | 540,278 |
| BK-R93R-52 | 2010 | 2011-07-01 | 1 | 182–182 | 3,578 |
| BK-R93R-52 | 2011 | 2011-07-01 | 131 | 1–176 | 468,718 |
| BK-R93R-56 | 2010 | 2011-07-01 | 1 | 182–182 | 3,578 |
| BK-R93R-56 | 2011 | 2011-07-01 | 135 | 2–181 | 483,030 |
| BK-R93R-62 | 2010 | 2011-07-01 | 2 | 183–184 | 7,156 |
| BK-R93R-62 | 2011 | 2011-07-01 | 164 | 1–180 | 586,792 |
| BK-T18U-44 | 2013 | 2013-07-01 | 23 | 4–171 | 17,066 |
| BK-T18U-50 | 2013 | 2013-07-01 | 26 | 3–173 | 19,292 |
| BK-T18U-54 | 2012 | 2013-07-01 | 1 | 183–183 | 742 |
| BK-T18U-54 | 2013 | 2013-07-01 | 19 | 15–179 | 14,098 |
| BK-T18U-58 | 2013 | 2013-07-01 | 26 | 1–172 | 19,292 |
| BK-T18U-62 | 2013 | 2013-07-01 | 21 | 6–151 | 15,582 |
| BK-T18Y-44 | 2013 | 2013-07-01 | 22 | 2–152 | 16,324 |
| BK-T18Y-50 | 2013 | 2013-07-01 | 25 | 7–179 | 18,550 |
| BK-T18Y-54 | 2013 | 2013-07-01 | 23 | 6–153 | 17,066 |
| BK-T18Y-58 | 2012 | 2013-07-01 | 2 | 182–185 | 1,484 |
| BK-T18Y-58 | 2013 | 2013-07-01 | 15 | 25–176 | 11,130 |
| BK-T18Y-62 | 2013 | 2013-07-01 | 18 | 8–162 | 13,356 |
| BK-T44U-46 | 2012 | 2013-07-01 | 2 | 183–185 | 2,430 |
| BK-T44U-46 | 2013 | 2013-07-01 | 46 | 8–166 | 55,890 |
| BK-T44U-50 | 2012 | 2013-07-01 | 1 | 184–184 | 1,215 |
| BK-T44U-50 | 2013 | 2013-07-01 | 41 | 4–181 | 49,815 |
| BK-T44U-54 | 2013 | 2013-07-01 | 37 | 4–175 | 44,955 |
| BK-T44U-60 | 2012 | 2013-07-01 | 1 | 183–183 | 1,215 |
| BK-T44U-60 | 2013 | 2013-07-01 | 34 | 1–169 | 41,310 |
| BK-T79U-46 | 2012 | 2013-07-01 | 2 | 184–185 | 4,768 |
| BK-T79U-46 | 2013 | 2013-07-01 | 56 | 6–181 | 133,504 |
| BK-T79U-50 | 2012 | 2013-07-01 | 1 | 182–182 | 2,384 |
| BK-T79U-50 | 2013 | 2013-07-01 | 60 | 3–178 | 143,040 |
| BK-T79U-54 | 2013 | 2013-07-01 | 53 | 4–181 | 126,352 |
| BK-T79U-60 | 2012 | 2013-07-01 | 1 | 183–183 | 2,384 |
| BK-T79U-60 | 2013 | 2013-07-01 | 52 | 3–170 | 123,968 |
| BK-T79Y-46 | 2013 | 2013-07-01 | 58 | 2–177 | 138,272 |
| BK-T79Y-50 | 2012 | 2013-07-01 | 2 | 182–182 | 4,768 |
| BK-T79Y-50 | 2013 | 2013-07-01 | 52 | 5–160 | 123,968 |
| BK-T79Y-54 | 2013 | 2013-07-01 | 57 | 1–159 | 135,888 |
| BK-T79Y-60 | 2013 | 2013-07-01 | 51 | 2–180 | 121,584 |
| CL-9009 | 2013 | 2013-07-01 | 384 | 1–181 | 3,080 |
| FE-6654 | 2012 | 2013-07-01 | 5 | 182–184 | 110 |
| FE-6654 | 2013 | 2013-07-01 | 882 | 1–181 | 19,404 |
| HY-1023-70 | 2012 | 2013-07-01 | 2 | 182–182 | 110 |
| HY-1023-70 | 2013 | 2013-07-01 | 303 | 2–179 | 16,665 |
| PK-7098 | 2012 | 2013-07-01 | 4 | 182–183 | 8 |
| PK-7098 | 2013 | 2013-07-01 | 1,357 | 1–181 | 2,714 |
| RA-H123 | 2013 | 2013-07-01 | 138 | 1–173 | 16,560 |
| SH-W890-L | 2013 | 2013-07-01 | 154 | 3–171 | 10,780 |
| SH-W890-M | 2013 | 2013-07-01 | 161 | 1–172 | 11,270 |
| SH-W890-S | 2013 | 2013-07-01 | 122 | 1–165 | 8,540 |
| SJ-0194-L | 2012 | 2013-07-01 | 2 | 182–183 | 108 |
| SJ-0194-L | 2013 | 2013-07-01 | 156 | 1–176 | 8,424 |
| SJ-0194-M | 2012 | 2013-07-01 | 1 | 184–184 | 54 |
| SJ-0194-M | 2013 | 2013-07-01 | 180 | 1–181 | 9,720 |
| SJ-0194-S | 2012 | 2013-07-01 | 1 | 183–183 | 54 |
| SJ-0194-S | 2013 | 2013-07-01 | 178 | 1–181 | 9,612 |
| SJ-0194-X | 2013 | 2013-07-01 | 158 | 2–180 | 8,532 |
| SO-R809-L | 2012 | 2013-07-01 | 2 | 183–183 | 18 |
| SO-R809-L | 2013 | 2013-07-01 | 112 | 3–162 | 1,008 |
| SO-R809-M | 2013 | 2013-07-01 | 134 | 2–175 | 1,206 |
| ST-1401 | 2012 | 2013-07-01 | 1 | 185–185 | 159 |
| ST-1401 | 2013 | 2013-07-01 | 118 | 2–166 | 18,762 |
| TI-M267 | 2013 | 2013-07-01 | 363 | 2–181 | 9,075 |
| TI-M602 | 2012 | 2013-07-01 | 1 | 184–184 | 30 |
| TI-M602 | 2013 | 2013-07-01 | 502 | 1–180 | 15,060 |
| TI-M823 | 2012 | 2013-07-01 | 4 | 182–185 | 140 |
| TI-M823 | 2013 | 2013-07-01 | 577 | 1–180 | 20,230 |
| TI-R092 | 2012 | 2013-07-01 | 5 | 182–185 | 105 |
| TI-R092 | 2013 | 2013-07-01 | 435 | 1–179 | 9,135 |
| TI-R628 | 2012 | 2013-07-01 | 2 | 183–184 | 50 |
| TI-R628 | 2013 | 2013-07-01 | 392 | 1–176 | 9,800 |
| TI-R982 | 2012 | 2013-07-01 | 4 | 182–185 | 132 |
| TI-R982 | 2013 | 2013-07-01 | 393 | 1–181 | 12,969 |
| TI-T723 | 2012 | 2013-07-01 | 2 | 183–185 | 58 |
| TI-T723 | 2013 | 2013-07-01 | 352 | 1–177 | 10,208 |
| TT-M928 | 2012 | 2013-07-01 | 3 | 183–185 | 15 |
| TT-M928 | 2013 | 2013-07-01 | 1,316 | 1–180 | 6,580 |
| TT-R982 | 2012 | 2013-07-01 | 7 | 182–185 | 28 |
| TT-R982 | 2013 | 2013-07-01 | 995 | 1–181 | 3,980 |
| TT-T092 | 2012 | 2013-07-01 | 2 | 183–185 | 10 |
| TT-T092 | 2013 | 2013-07-01 | 591 | 1–175 | 2,955 |
| VE-C304-L | 2013 | 2013-07-01 | 67 | 4–180 | 4,288 |
| VE-C304-M | 2013 | 2013-07-01 | 72 | 2–179 | 4,608 |
| VE-C304-S | 2012 | 2013-07-01 | 1 | 182–182 | 64 |
| VE-C304-S | 2013 | 2013-07-01 | 66 | 1–178 | 4,224 |
| WB-H098 | 2012 | 2013-07-01 | 18 | 182–185 | 90 |
| WB-H098 | 2013 | 2013-07-01 | 1,737 | 1–181 | 8,710 |
