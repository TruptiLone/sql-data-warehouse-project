
/*
=============================================================
Project: RetailFlow 360 - SQL Data Warehouse
File: scripts/init_database.sql
Database: DataWarehouse
Platform: Microsoft Azure SQL Database

Description:
    Initializes the Bronze, Silver, and Gold schemas
    for the Data Warehouse project.

Azure Setup:
    Resource Group: rg-retailflow-datawarehouse
    Database: DataWarehouse
    Pricing Tier: Free - General Purpose - Serverless

Prerequisites:
    1. Azure SQL Database has been created.
    2. Network access has been configured.
    3. VS Code is connected to DataWarehouse.

Important:
    - Do NOT execute USE master.
    - Do NOT create or drop the database.
    - This script is safe to run multiple times.
=============================================================
*/

-- ==========================================================
-- STEP 1: Verify Database Connection
-- ==========================================================

SELECT
    DB_NAME() AS current_database,
    GETDATE() AS current_datetime;

GO

-- Safety check: ensure we are using the correct database

IF DB_NAME() <> 'DataWarehouse'
BEGIN
    THROW 50001,
        'Connect to DataWarehouse before running this script.',
        1;
END;

GO

-- ==========================================================
-- STEP 2: Create Bronze Schema
-- ==========================================================

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'bronze'
)
BEGIN
    EXEC('CREATE SCHEMA bronze');
    PRINT 'Bronze schema created successfully.';
END
ELSE
BEGIN
    PRINT 'Bronze schema already exists.';
END;

GO

-- ==========================================================
-- STEP 3: Create Silver Schema
-- ==========================================================

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'silver'
)
BEGIN
    EXEC('CREATE SCHEMA silver');
    PRINT 'Silver schema created successfully.';
END
ELSE
BEGIN
    PRINT 'Silver schema already exists.';
END;

GO

-- ==========================================================
-- STEP 4: Create Gold Schema
-- ==========================================================

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'gold'
)
BEGIN
    EXEC('CREATE SCHEMA gold');
    PRINT 'Gold schema created successfully.';
END
ELSE
BEGIN
    PRINT 'Gold schema already exists.';
END;

GO

-- ==========================================================
-- STEP 5: Verify All Warehouse Schemas
-- ==========================================================

SELECT
    name AS schema_name,
    schema_id
FROM sys.schemas
WHERE name IN ('bronze', 'silver', 'gold')
ORDER BY
    CASE name
        WHEN 'bronze' THEN 1
        WHEN 'silver' THEN 2
        WHEN 'gold' THEN 3
    END;

GO

PRINT 'Data Warehouse initialization completed.';
