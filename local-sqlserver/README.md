# RetailFlow 360 — Local SQL Server Development

This folder is a fresh, isolated workspace for developing and testing the RetailFlow 360 data warehouse with SQL Server in Docker on a Mac.

## Purpose

- Continue Bronze, Silver, and Gold development without consuming Azure SQL Database's monthly free allowance.
- Keep the existing Azure SQL deployment and existing `scripts/` untouched.
- Reuse or adapt the existing T-SQL logic for a separate **local** `DataWarehouse` database.
- Document reproducible setup, loading, quality checks, and testing.

## Current local setup

A SQL Server 2022 Developer container named `retailflow-sql-local` was created with:
- Local endpoint: `127.0.0.1,14333`
- Docker volume: `retailflow_sql_data`
- Platform: `linux/amd64` (emulated on Apple Silicon; not officially supported by Microsoft)

**Container health and SQL connectivity have not yet been confirmed.**

## Safety rules

1. Never connect setup scripts to the Azure SQL server when working on local development.
2. Never commit passwords, connection strings with credentials, tokens, or raw private datasets.
3. Do not delete Docker volumes or existing SQL databases.
4. Review existing scripts before executing `DROP`, `TRUNCATE`, `DELETE`, or `EXEC` commands.
5. Keep local runtime secrets in ignored environment files; commit only example placeholders.
6. Treat the existing repository's `scripts/` directory as the starting codebase, not as files to overwrite automatically.

## First verification (run from any folder on the Mac)

```bash
docker ps -a --filter name=retailflow-sql-local
docker logs --tail 40 retailflow-sql-local
```

If the container is healthy, connect from VS Code's MSSQL extension to `localhost,14333` with SQL Login `sa`, then create a **separate local** `DataWarehouse` database and import the original source CSV files.
