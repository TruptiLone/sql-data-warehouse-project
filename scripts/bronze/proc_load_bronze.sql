
/*
===============================================================================
Stored Procedure: Load Bronze Layer (Azure Blob Storage -> Bronze)
===============================================================================
Purpose:
    Loads six CRM and ERP datasets into the Bronze layer.

Features:
    - Full-refresh ingestion using TRUNCATE TABLE
    - BULK INSERT from Azure Blob Storage
    - Separate CRM and ERP loading stages
    - Logging before each truncate and insert
    - Individual table load duration
    - Total batch duration
    - TRY...CATCH error handling
    - Error propagation using THROW

WARNING:
    Existing Bronze records are deleted before each import.
    This procedure does not provide atomic rollback of all six loads.
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @start_time DATETIME2,
        @end_time DATETIME2,
        @batch_start_time DATETIME2,
        @batch_end_time DATETIME2;

    BEGIN TRY

        SET @batch_start_time = SYSDATETIME();

        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '================================================';

        -- ==================================================
        -- CRM TABLES
        -- ==================================================

        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';

        -- 1. CRM Customer Information

        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT '>> Inserting Data Into: bronze.crm_cust_info';

        BULK INSERT bronze.crm_cust_info
        FROM 'source_crm/cust_info.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';


        -- 2. CRM Product Information

        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '>> Inserting Data Into: bronze.crm_prd_info';

        BULK INSERT bronze.crm_prd_info
        FROM 'source_crm/prd_info.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';


        -- 3. CRM Sales Details

        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '>> Inserting Data Into: bronze.crm_sales_details';

        BULK INSERT bronze.crm_sales_details
        FROM 'source_crm/sales_details.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';


        -- ==================================================
        -- ERP TABLES
        -- ==================================================

        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';

        -- 4. ERP Customer Demographics

        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT '>> Inserting Data Into: bronze.erp_cust_az12';

        BULK INSERT bronze.erp_cust_az12
        FROM 'source_erp/CUST_AZ12.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';


        -- 5. ERP Location Information

        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT '>> Inserting Data Into: bronze.erp_loc_a101';

        BULK INSERT bronze.erp_loc_a101
        FROM 'source_erp/LOC_A101.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';


        -- 6. ERP Product Categories

        SET @start_time = SYSDATETIME();

        PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: bronze.erp_px_cat_g1v2';

        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'source_erp/PX_CAT_G1V2.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"',
            TABLOCK
        );

        SET @end_time = SYSDATETIME();

        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
            + ' seconds';
        PRINT '>> -------------';


        -- ==================================================
        -- BATCH EXECUTION SUMMARY
        -- ==================================================

        SET @batch_end_time = SYSDATETIME();

        PRINT '================================================';
        PRINT 'Loading Bronze Layer is Completed';

        PRINT '   - Total Load Duration: '
            + CAST(
                DATEDIFF(SECOND, @batch_start_time, @batch_end_time)
                AS VARCHAR(20)
              )
            + ' seconds';

        PRINT '================================================';

    END TRY

    BEGIN CATCH

        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER';

        PRINT 'Error Message: ' + ERROR_MESSAGE();

        PRINT 'Error Number: '
            + CAST(ERROR_NUMBER() AS VARCHAR(20));

        PRINT 'Error State: '
            + CAST(ERROR_STATE() AS VARCHAR(20));

        PRINT '================================================';

        THROW;

    END CATCH
END;
GO
