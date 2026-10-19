# Local SQL Server setup and operation

## Verified setup

Verified on 2026-10-19: SQL Server 2022 Developer (RTM-CU27-GDR), version 16.0.4305.5, started successfully and executed `SELECT @@VERSION`.

- Container: `retailflow-sql-local`
- Image: `mcr.microsoft.com/mssql/server:2022-latest`
- Platform: `linux/amd64`, emulated on Apple Silicon
- Local endpoint: `127.0.0.1,14333`
- Memory limit: 4 GB (Docker Desktop has approximately 8 GB)
- Persistent volume: `local-sqlserver_retailflow_sql_fresh`, mounted at `/var/opt/mssql`
- The pre-existing `retailflow_sql_data` volume is preserved and is not used by this service.
- Password: generated locally in Git-ignored `.env`, with owner-only permissions (600). Never commit this file.

Microsoft does not test or support SQL Server under Rosetta/QEMU emulation. Successful startup and short-term query checks do not guarantee long-term reliability. If emulation becomes unstable, use SQL Server on an Intel/AMD x86-64 Linux host or a supported Windows machine and connect remotely from VS Code. No cloud resources were changed by this setup.

## Connect from VS Code

Install Microsoft's **SQL Server (mssql)** extension. Run **MS SQL: Connect** from the Command Palette and create a connection:

| Setting | Value |
| --- | --- |
| Profile name | RetailFlow 360 Local |
| Server | `127.0.0.1,14333` |
| Authentication | SQL Login |
| User | `sa` |
| Password | Value of `MSSQL_SA_PASSWORD` in the local `.env` |
| Database | `DataWarehouse` (`master` only for initialization) |
| Encrypt | Enabled / Mandatory |
| Trust server certificate | True (local self-signed certificate) |

To copy the password into the macOS clipboard without printing it, run from the repository root:

```bash
python3 - <<'PYCODE'
from pathlib import Path
import subprocess
value = Path('local-sqlserver/.env').read_text().strip().split('=', 1)[1]
subprocess.run(['pbcopy'], input=value.encode(), check=True)
PYCODE
```

Paste into the extension's password field; do not paste into SQL scripts or settings files. Clear the clipboard afterward with `pbcopy < /dev/null`.

Open a SQL editor on this connection and execute:

```sql
SELECT @@VERSION;
SELECT DB_NAME() AS current_database;
```

DataWarehouse and its bronze, silver, and gold schemas are initialized locally. All six Bronze and all six Silver tables are loaded; Gold remains planned. See [the local Bronze loading guide](../scripts/bronze/README.md) for the reproducible loading process and results.

## Safe lifecycle commands

Run from the repository root:

```bash
# Validate without printing expanded credentials.
docker compose --project-directory local-sqlserver config --quiet

# Start again using the existing persistent volume.
docker compose --project-directory local-sqlserver up -d

# Inspect status and recent startup messages.
docker compose --project-directory local-sqlserver ps
docker compose --project-directory local-sqlserver logs --tail 40 sqlserver

# Stop without removing the container or database storage.
docker compose --project-directory local-sqlserver stop
```

Do not use `down -v`, volume removal, or database reset commands. Do not regenerate `.env` for an initialized volume: changing the environment variable does not change an existing database login's password.

To repeat the SQL connection check without exposing the password:

```bash
docker compose --project-directory local-sqlserver exec -T sqlserver sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -b -l 15 -Q "SET NOCOUNT ON; SELECT @@VERSION;"'
```

Avoid plain `docker compose config` and unfiltered `docker inspect` because they can print credentials. The `2022-latest` image tag can change; avoid pulling/recreating casually when preserving a working development environment.

## References

- [Microsoft container deployment and platform support](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-docker-container-deployment?view=sql-server-ver16)
- [VS Code MSSQL connections](https://learn.microsoft.com/en-us/sql/tools/visual-studio-code-extensions/mssql/mssql-database-connections)



## Prerequisites and local data

Use Python 3, Docker Desktop, and the SQLCMD client already bundled inside the
SQL Server image. Python uses the standard library; no pip dependencies are needed.
Canonical course CSVs must be supplied locally; they are not downloaded or
committed. Keep them under `local-sqlserver/datasets/source_crm/` and `source_erp/`.
The read-only bind source must exist before Compose starts:

```bash
mkdir -p local-sqlserver/datasets/source_crm local-sqlserver/datasets/source_erp
```

For a fresh environment only, create `.env` from `.env.example` in your editor,
replace the placeholder with a strong password, and apply `chmod 600
local-sqlserver/.env`. Do not overwrite an existing `.env` or regenerate the
password for an initialized database volume. No real password belongs in code,
documentation, terminal output, or Git.

The source files are `cust_info.csv`, `prd_info.csv`, `sales_details.csv`,
`CUST_AZ12.csv`, `LOC_A101.csv`, and `PX_CAT_G1V2.csv`. Duplicate datasets outside
this folder are ignored and not used. Generated `.bulk/` copies are also ignored.

## Execution order

Run commands from the repository root. All SQL commands below explicitly target
the named local Docker container. SQLCMD mode is required for error-stop directives.
Do not execute the original Azure-oriented scripts under the root `scripts/`.

```bash
# 1. Create only a missing database/schemas. Existing state is preserved.
docker exec -i retailflow-sql-local sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -S tcp:127.0.0.1,1433 -U sa -C -b -l 15 -d master' < local-sqlserver/scripts/init_database.sql

# 2. Create only missing Bronze tables, validating existing definitions.
docker exec -i retailflow-sql-local sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -S tcp:127.0.0.1,1433 -U sa -C -b -l 15 -d DataWarehouse' < local-sqlserver/scripts/bronze/ddl_bronze.sql

# 3. CSV-aware preparation, local Bronze load, complete row validation.
python3 local-sqlserver/scripts/bronze/load_bronze.py

# 4. Execute reviewed Silver phases in dependency order.
python3 local-sqlserver/scripts/silver/run_crm.py
python3 local-sqlserver/scripts/silver/run_sales.py
python3 local-sqlserver/scripts/silver/run_erp.py
```

Before initial Silver loading, inspect the corresponding read-only profile files
using the same local SQLCMD command (substitute the SQL input path). Runners do
not automatically execute profiles. They execute their own DDL, load, quality,
and rerun checks. Do not use `python -O`: some safety/validation checks use assertions.

For read-only validation without loading, run:

```bash
docker exec -i retailflow-sql-local sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -S tcp:127.0.0.1,1433 -U sa -C -b -l 15 -d DataWarehouse' < local-sqlserver/scripts/silver/quality_checks.sql
docker exec -i retailflow-sql-local sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -S tcp:127.0.0.1,1433 -U sa -C -b -l 15 -d DataWarehouse' < local-sqlserver/scripts/silver/quality_sales.sql
docker exec -i retailflow-sql-local sh -c 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -S tcp:127.0.0.1,1433 -U sa -C -b -l 15 -d DataWarehouse' < local-sqlserver/scripts/silver/quality_erp.sql
```

The Python connection helper deliberately verifies the exact known image ID,
container name, named volume, and mount source. A fresh machine may pull a
different `2022-latest` image; inspect the replacement environment before making
an intentional configuration update. The current scripts are a verified local
snapshot, not an automatically portable deployment package.

Adding/changing the bind mount recreates the container while preserving the named
database volume. Such a change briefly interrupts SQL Server. No recreation is
needed merely to run the existing loaders or inspect data. Stop on a populated
Silver mismatch; do not reset data to make a rerun pass.

See the [full implementation guide](IMPLEMENTATION_GUIDE.md),
[Bronze guide](../scripts/bronze/README.md), [CRM guide](../scripts/silver/README.md),
[sales rules](../scripts/silver/SALES.md), and [ERP rules](../scripts/silver/ERP.md).
