/* RetailFlow 360: local SQL Server database and schemas only.
   Run with sqlcmd -b against the verified retailflow-sql-local container.
   No tables or data are created or modified. Safe to run repeatedly.
   SQLCMD mode is required so a failed guard stops subsequent batches.
*/
:ON ERROR EXIT

USE [master];
GO

SET NOCOUNT ON;

-- Reject cloud engines and non-Developer instances before any changes.
IF CONVERT(int, SERVERPROPERTY('EngineEdition')) <> 3
   OR CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
BEGIN
    THROW 50001, 'Expected the verified local SQL Server Developer container. Stopping.', 1;
END;

IF DB_ID(N'DataWarehouse') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE [DataWarehouse];');
    PRINT 'Created database DataWarehouse.';
END
ELSE
    PRINT 'Database DataWarehouse already exists; preserved.';

IF EXISTS (
    SELECT 1 FROM sys.databases
    WHERE name = N'DataWarehouse' AND (state_desc <> N'ONLINE' OR is_read_only = 1)
)
BEGIN
    THROW 50002, 'DataWarehouse is not online and writable. Inspect before proceeding.', 1;
END;
GO

USE [DataWarehouse];
GO

IF SCHEMA_ID(N'bronze') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA [bronze] AUTHORIZATION [dbo];');
    PRINT 'Created schema bronze.';
END
ELSE
    PRINT 'Schema bronze already exists; preserved.';

IF SCHEMA_ID(N'silver') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA [silver] AUTHORIZATION [dbo];');
    PRINT 'Created schema silver.';
END
ELSE
    PRINT 'Schema silver already exists; preserved.';

IF SCHEMA_ID(N'gold') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA [gold] AUTHORIZATION [dbo];');
    PRINT 'Created schema gold.';
END
ELSE
    PRINT 'Schema gold already exists; preserved.';

IF DB_NAME() <> N'DataWarehouse'
   OR SCHEMA_ID(N'bronze') IS NULL
   OR SCHEMA_ID(N'silver') IS NULL
   OR SCHEMA_ID(N'gold') IS NULL
BEGIN
    THROW 50003, 'Database or schema validation failed.', 1;
END;

SELECT name AS database_name, state_desc, is_read_only
FROM sys.databases WHERE name = N'DataWarehouse';

SELECT name AS schema_name, USER_NAME(principal_id) AS schema_owner
FROM sys.schemas WHERE name IN (N'bronze', N'silver', N'gold')
ORDER BY name;

SELECT COUNT(*) AS user_table_count FROM sys.tables WHERE is_ms_shipped = 0;
PRINT 'Database and all three schemas verified.';
GO
