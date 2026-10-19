/* RetailFlow 360: local Bronze tables only. Run using sqlcmd -b -d DataWarehouse
   in the verified retailflow-sql-local Docker container. No data loading.
   Column definitions match scripts/bronze/ddl_bronze.sql; NULL is explicit.
   Existing tables are preserved; incompatible definitions stop execution.
   All six local CSV headers verified: 32 columns in matching order.
   ERP CSV headers are uppercase; original DDL lowercase names are preserved.
*/
:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'DataWarehouse'
   OR CONVERT(int, SERVERPROPERTY('EngineEdition')) <> 3
   OR CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
    THROW 50100, 'Expected DataWarehouse on the verified local Developer container.', 1;
IF SCHEMA_ID(N'bronze') IS NULL
    THROW 50101, 'Expected existing bronze schema. Stopping.', 1;

DECLARE @expected TABLE (
    table_name sysname, ordinal int, column_name sysname,
    type_name sysname, max_length smallint
);
INSERT INTO @expected VALUES
(N'crm_cust_info', 1, N'cst_id', N'int', 4),
(N'crm_cust_info', 2, N'cst_key', N'nvarchar', 100),
(N'crm_cust_info', 3, N'cst_firstname', N'nvarchar', 100),
(N'crm_cust_info', 4, N'cst_lastname', N'nvarchar', 100),
(N'crm_cust_info', 5, N'cst_marital_status', N'nvarchar', 100),
(N'crm_cust_info', 6, N'cst_gndr', N'nvarchar', 100),
(N'crm_cust_info', 7, N'cst_create_date', N'date', 3),
(N'crm_prd_info', 1, N'prd_id', N'int', 4),
(N'crm_prd_info', 2, N'prd_key', N'nvarchar', 100),
(N'crm_prd_info', 3, N'prd_nm', N'nvarchar', 100),
(N'crm_prd_info', 4, N'prd_cost', N'int', 4),
(N'crm_prd_info', 5, N'prd_line', N'nvarchar', 100),
(N'crm_prd_info', 6, N'prd_start_dt', N'datetime', 8),
(N'crm_prd_info', 7, N'prd_end_dt', N'datetime', 8),
(N'crm_sales_details', 1, N'sls_ord_num', N'nvarchar', 100),
(N'crm_sales_details', 2, N'sls_prd_key', N'nvarchar', 100),
(N'crm_sales_details', 3, N'sls_cust_id', N'int', 4),
(N'crm_sales_details', 4, N'sls_order_dt', N'int', 4),
(N'crm_sales_details', 5, N'sls_ship_dt', N'int', 4),
(N'crm_sales_details', 6, N'sls_due_dt', N'int', 4),
(N'crm_sales_details', 7, N'sls_sales', N'int', 4),
(N'crm_sales_details', 8, N'sls_quantity', N'int', 4),
(N'crm_sales_details', 9, N'sls_price', N'int', 4),
(N'erp_loc_a101', 1, N'cid', N'nvarchar', 100),
(N'erp_loc_a101', 2, N'cntry', N'nvarchar', 100),
(N'erp_cust_az12', 1, N'cid', N'nvarchar', 100),
(N'erp_cust_az12', 2, N'bdate', N'date', 3),
(N'erp_cust_az12', 3, N'gen', N'nvarchar', 100),
(N'erp_px_cat_g1v2', 1, N'id', N'nvarchar', 100),
(N'erp_px_cat_g1v2', 2, N'cat', N'nvarchar', 100),
(N'erp_px_cat_g1v2', 3, N'subcat', N'nvarchar', 100),
(N'erp_px_cat_g1v2', 4, N'maintenance', N'nvarchar', 100);

BEGIN TRY
    BEGIN TRANSACTION;

    -- Compare all columns in existing target objects before making changes.
    IF EXISTS (
        SELECT 1 FROM sys.objects o
        WHERE o.schema_id = SCHEMA_ID(N'bronze')
          AND o.name IN (SELECT table_name FROM @expected) AND o.type <> 'U'
    )
        THROW 50102, 'An existing target name is not a user table. Stopping.', 1;

    IF EXISTS (
        SELECT e.table_name, e.ordinal, e.column_name, e.type_name, e.max_length, 1, 0, 0
        FROM @expected e
        WHERE OBJECT_ID(N'bronze.' + e.table_name, N'U') IS NOT NULL
        EXCEPT
        SELECT t.name, c.column_id, c.name, TYPE_NAME(c.user_type_id), c.max_length,
               CONVERT(int,c.is_nullable), CONVERT(int,c.is_identity), CONVERT(int,c.is_computed)
        FROM sys.tables t JOIN sys.columns c ON c.object_id = t.object_id
        WHERE t.schema_id = SCHEMA_ID(N'bronze') AND t.name IN (SELECT table_name FROM @expected)
    ) OR EXISTS (
        SELECT t.name, c.column_id, c.name, TYPE_NAME(c.user_type_id), c.max_length
        FROM sys.tables t JOIN sys.columns c ON c.object_id = t.object_id
        WHERE t.schema_id = SCHEMA_ID(N'bronze') AND t.name IN (SELECT table_name FROM @expected)
        EXCEPT
        SELECT table_name, ordinal, column_name, type_name, max_length FROM @expected
    )
        THROW 50103, 'Existing Bronze columns differ from the original specification. Stopping.', 1;

    IF OBJECT_ID(N'bronze.crm_cust_info', N'U') IS NULL
    BEGIN
        CREATE TABLE [bronze].[crm_cust_info] (
        [cst_id] INT NULL,
        [cst_key] NVARCHAR(50) NULL,
        [cst_firstname] NVARCHAR(50) NULL,
        [cst_lastname] NVARCHAR(50) NULL,
        [cst_marital_status] NVARCHAR(50) NULL,
        [cst_gndr] NVARCHAR(50) NULL,
        [cst_create_date] DATE NULL
        );
        PRINT 'Created bronze.crm_cust_info.';
    END
    ELSE
        PRINT 'Preserved bronze.crm_cust_info.';

    IF OBJECT_ID(N'bronze.crm_prd_info', N'U') IS NULL
    BEGIN
        CREATE TABLE [bronze].[crm_prd_info] (
        [prd_id] INT NULL,
        [prd_key] NVARCHAR(50) NULL,
        [prd_nm] NVARCHAR(50) NULL,
        [prd_cost] INT NULL,
        [prd_line] NVARCHAR(50) NULL,
        [prd_start_dt] DATETIME NULL,
        [prd_end_dt] DATETIME NULL
        );
        PRINT 'Created bronze.crm_prd_info.';
    END
    ELSE
        PRINT 'Preserved bronze.crm_prd_info.';

    IF OBJECT_ID(N'bronze.crm_sales_details', N'U') IS NULL
    BEGIN
        CREATE TABLE [bronze].[crm_sales_details] (
        [sls_ord_num] NVARCHAR(50) NULL,
        [sls_prd_key] NVARCHAR(50) NULL,
        [sls_cust_id] INT NULL,
        [sls_order_dt] INT NULL,
        [sls_ship_dt] INT NULL,
        [sls_due_dt] INT NULL,
        [sls_sales] INT NULL,
        [sls_quantity] INT NULL,
        [sls_price] INT NULL
        );
        PRINT 'Created bronze.crm_sales_details.';
    END
    ELSE
        PRINT 'Preserved bronze.crm_sales_details.';

    IF OBJECT_ID(N'bronze.erp_loc_a101', N'U') IS NULL
    BEGIN
        CREATE TABLE [bronze].[erp_loc_a101] (
        [cid] NVARCHAR(50) NULL,
        [cntry] NVARCHAR(50) NULL
        );
        PRINT 'Created bronze.erp_loc_a101.';
    END
    ELSE
        PRINT 'Preserved bronze.erp_loc_a101.';

    IF OBJECT_ID(N'bronze.erp_cust_az12', N'U') IS NULL
    BEGIN
        CREATE TABLE [bronze].[erp_cust_az12] (
        [cid] NVARCHAR(50) NULL,
        [bdate] DATE NULL,
        [gen] NVARCHAR(50) NULL
        );
        PRINT 'Created bronze.erp_cust_az12.';
    END
    ELSE
        PRINT 'Preserved bronze.erp_cust_az12.';

    IF OBJECT_ID(N'bronze.erp_px_cat_g1v2', N'U') IS NULL
    BEGIN
        CREATE TABLE [bronze].[erp_px_cat_g1v2] (
        [id] NVARCHAR(50) NULL,
        [cat] NVARCHAR(50) NULL,
        [subcat] NVARCHAR(50) NULL,
        [maintenance] NVARCHAR(50) NULL
        );
        PRINT 'Created bronze.erp_px_cat_g1v2.';
    END
    ELSE
        PRINT 'Preserved bronze.erp_px_cat_g1v2.';

    -- Compare all columns in existing target objects before making changes.
    IF EXISTS (
        SELECT 1 FROM sys.objects o
        WHERE o.schema_id = SCHEMA_ID(N'bronze')
          AND o.name IN (SELECT table_name FROM @expected) AND o.type <> 'U'
    )
        THROW 50102, 'An existing target name is not a user table. Stopping.', 1;

    IF EXISTS (
        SELECT e.table_name, e.ordinal, e.column_name, e.type_name, e.max_length, 1, 0, 0
        FROM @expected e
        WHERE OBJECT_ID(N'bronze.' + e.table_name, N'U') IS NOT NULL
        EXCEPT
        SELECT t.name, c.column_id, c.name, TYPE_NAME(c.user_type_id), c.max_length,
               CONVERT(int,c.is_nullable), CONVERT(int,c.is_identity), CONVERT(int,c.is_computed)
        FROM sys.tables t JOIN sys.columns c ON c.object_id = t.object_id
        WHERE t.schema_id = SCHEMA_ID(N'bronze') AND t.name IN (SELECT table_name FROM @expected)
    ) OR EXISTS (
        SELECT t.name, c.column_id, c.name, TYPE_NAME(c.user_type_id), c.max_length
        FROM sys.tables t JOIN sys.columns c ON c.object_id = t.object_id
        WHERE t.schema_id = SCHEMA_ID(N'bronze') AND t.name IN (SELECT table_name FROM @expected)
        EXCEPT
        SELECT table_name, ordinal, column_name, type_name, max_length FROM @expected
    )
        THROW 50103, 'Existing Bronze columns differ from the original specification. Stopping.', 1;

    IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N'bronze')
        AND name IN (SELECT table_name FROM @expected)) <> 6
        THROW 50104, 'Expected all six Bronze tables.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT t.name AS table_name, c.column_id, c.name AS column_name,
       TYPE_NAME(c.user_type_id) AS type_name, c.max_length AS max_length_bytes, c.is_nullable
FROM sys.tables t JOIN sys.columns c ON c.object_id = t.object_id
WHERE t.schema_id = SCHEMA_ID(N'bronze') AND t.name IN (SELECT table_name FROM @expected)
ORDER BY t.name, c.column_id;

SELECT N'crm_cust_info' AS table_name, COUNT_BIG(*) AS row_count FROM bronze.[crm_cust_info]
UNION ALL
SELECT N'crm_prd_info' AS table_name, COUNT_BIG(*) AS row_count FROM bronze.[crm_prd_info]
UNION ALL
SELECT N'crm_sales_details' AS table_name, COUNT_BIG(*) AS row_count FROM bronze.[crm_sales_details]
UNION ALL
SELECT N'erp_loc_a101' AS table_name, COUNT_BIG(*) AS row_count FROM bronze.[erp_loc_a101]
UNION ALL
SELECT N'erp_cust_az12' AS table_name, COUNT_BIG(*) AS row_count FROM bronze.[erp_cust_az12]
UNION ALL
SELECT N'erp_px_cat_g1v2' AS table_name, COUNT_BIG(*) AS row_count FROM bronze.[erp_px_cat_g1v2]
ORDER BY table_name;
