# RetailFlow 360 — Local Data Warehouse

A local SQL Server warehouse that turns CRM and ERP CSV extracts into validated
customer, product, and sales datasets. **Bronze and all six Silver tables are
implemented. Gold dimensional modeling is planned.** Original source scripts and
Azure resources are separate from this local workflow.

## Architecture and stack

```text
CRM + ERP CSVs → Bronze (typed raw records) → Silver (cleaned and reconciled)
                                                   → Gold (planned) → reporting
```

- SQL Server 2022 Developer in Docker, database `DataWarehouse`.
- T-SQL for set-based transformations, transactions, and quality assertions.
- Python 3 standard library for CSV parsing, orchestration, and row comparisons.
- VS Code MSSQL, Git, and GitHub for development and version control.
- Local endpoint: **127.0.0.1:14333**; container `retailflow-sql-local`.
- Persistent SQL volume and read-only dataset mount; secrets/source data ignored.

## Implemented tables and results

Verified local snapshot: **2026-10-19**. Each name exists in both schemas.

| Table | Bronze rows | Silver rows |
|---|---:|---:|
| `crm_cust_info` | 18,494 | 18,484 |
| `crm_prd_info` | 397 | 397 |
| `crm_sales_details` | 60,398 | 60,398 |
| `erp_cust_az12` | 18,484 | 18,484 |
| `erp_loc_a101` | 18,484 | 18,484 |
| `erp_px_cat_g1v2` | 37 | 37 |
| **Total table rows** | **116,294** | **116,284** |

- Customers: 4 NULL IDs excluded, 6 excess duplicate occurrences consolidated.
- Products: all versions retained; 200 end dates repaired.
- Sales: all 60,398 rows retained; 35 monetary corrections, zero instructor-rule
  violations. The monetary assumption still needs business confirmation.
- ERP: normalized customer/location IDs and values; 16 future birthdates set NULL.
- Reruns preserve matching populated tables and timestamps; mismatches stop.
  Bronze stays unchanged. No destructive refresh or incremental/CDC update exists.

Known exceptions remain visible: **19 unknown order dates**, **18,410 sales before
recorded product history**, **22 retained birthdates over 100 years old**, and the
**CO_PE / CO_PD category mismatch affecting 7 CRM products**. Passing checks does
not erase these integration or business-policy questions.

## Setup, run, and inspect

Start with [local setup and execution order](docs/LOCAL_SETUP.md), including SQLCMD
initialization and Bronze DDL. Supply course CSVs locally; they are not in Git.
Run the supported phases from the repository root:

```bash
python3 local-sqlserver/scripts/bronze/load_bronze.py
python3 local-sqlserver/scripts/silver/run_crm.py
python3 local-sqlserver/scripts/silver/run_sales.py
python3 local-sqlserver/scripts/silver/run_erp.py
```

Use the setup guide's **read-only validation commands** when you only want to
inspect results. The runners verify the known local Docker configuration; review
that configuration before using a different image/machine. Apple Silicon uses
AMD64 emulation and is not a production support claim.

## Documentation and next milestone

- [Detailed implementation and data-quality guide](docs/IMPLEMENTATION_GUIDE.md)
- [Bronze ingestion](scripts/bronze/README.md)
- [CRM customers/products](scripts/silver/README.md)
- [Sales rules](scripts/silver/SALES.md) and [final read-only audit](scripts/silver/SALES_AUDIT.md)
- [ERP rules, distributions, and integration warnings](scripts/silver/ERP.md)

Gold is planned: customer/product dimensions and a sales fact with explicit
unknown keys and historical-match status. Preserve the 60,398-row sales grain;
resolve temporal/category attribution policy before building analytical joins.
