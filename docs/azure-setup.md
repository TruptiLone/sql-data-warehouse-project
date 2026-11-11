# sql-data-warehouse-project
Building a modern data warehouse with SQL Server, including ETL processes, data modeling, and analytics.
## Azure SQL Database — Development Environment

### Overview

This project implements a SQL Data Warehouse using Microsoft Azure SQL Database and follows the Medallion Architecture (Bronze, Silver, and Gold).

### Technology Stack

| Component | Technology |
|---|---|
| Cloud Provider | Microsoft Azure |
| Database | Azure SQL Database |
| Database Engine | Microsoft SQL Server (T-SQL) |
| Development Environment | macOS (Apple Silicon) |
| SQL Editor | Visual Studio Code |
| Database Extension | SQL Server (mssql) |
| Authentication | Microsoft Entra ID |
| Pricing Tier | Azure SQL Database Free — Serverless |

### Cloud Infrastructure

The database is hosted on Azure SQL Database using a serverless compute configuration.

The environment includes:

- Azure SQL logical server
- Azure SQL database named `DataWarehouse`
- Free serverless compute tier with auto-pause configured for free-tier usage limits
- Firewall rules restricting access to approved client IP addresses
- Encrypted database connections

Actual server addresses, administrator credentials, subscription identifiers, and firewall IP addresses are intentionally excluded from this repository.

### Database Initialization

The database was provisioned through the Azure Portal.

The `scripts/init_database.sql` script initializes the warehouse schemas:

- `bronze` — Raw source data
- `silver` — Cleaned and standardized data
- `gold` — Business-ready analytical models

The initialization script verifies the selected database and creates schemas only if they do not already exist.

### Database Connection

The database can be accessed using Visual Studio Code with Microsoft's SQL Server (mssql) extension.

Connection parameters:

| Parameter | Value |
|---|---|
| Server | `<YOUR_AZURE_SQL_SERVER>.database.windows.net` |
| Database | `DataWarehouse` |
| Port | `1433` |
| Authentication | Microsoft Entra ID |
| Encryption | Enabled |
| Trust Server Certificate | Disabled |


