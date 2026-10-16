
/*
=============================================================
Project: RetailFlow 360 - SQL Data Warehouse
File: init_database.sql
=============================================================

Script Purpose:
    Initialize the DataWarehouse database schemas
    using Azure SQL Database.

    The database is provisioned separately in Azure.

    This script:
    1. Verifies the database connection.
    2. Creates the Bronze schema if it does not exist.
    3. Creates the Silver schema if it does not exist.
    4. Creates the Gold schema if it does not exist.
    5. Verifies successful schema initialization.

Important:
    - Does NOT drop or recreate the database.
    - Does NOT delete existing tables or data.
    - Safe to execute multiple times.

=============================================================
*/

-- ==========================================================
-- Step 1: Verify Database Connection
-- ==========================================================

IF DB_NAME() <> 'DataWarehouse'
BEGIN
    THROW 50001,
        'Please connect to DataWarehouse before running.',
        1;
END;
GO

PRINT 'Connected to DataWarehouse successfully.';
GO


-- ==========================================================
-- Step 2: Create Bronze Schema
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
-- Step 3: Create Silver Schema
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
-- Step 4: Create Gold Schema
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
-- Step 5: Verify Schemas
-- ==========================================================

SELECT
    name AS schema_name,
    schema_id
FROM sys.schemas
WHERE name IN ('bronze', 'silver', 'gold')
ORDER BY name;
GO

PRINT 'Data Warehouse schema initialization completed.';
GO
