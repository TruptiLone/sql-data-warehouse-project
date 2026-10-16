
/*
=============================================================
Stored Procedure: Load Bronze Layer
Project: RetailFlow 360
Database: DataWarehouse
=============================================================

Purpose:
    Reload all six Bronze tables from Azure Blob Storage.

Source:
    Azure Blob Storage - bronze-source

External Data Source:
    RetailFlowBulkSource

WARNING:
    This is a full-refresh process.
    Existing Bronze records are removed before reloading.
=============================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2 = SYSDATETIME();

    BEGIN TRY

        PRINT '=========================================';
        PRINT 'Starting Bronze Layer ETL';
        PRINT '=========================================';

        -- =========================================
        -- CRM CUSTOMER INFORMATION
        -- =========================================

        PRINT 'Loading CRM Customers';

        TRUNCATE TABLE bronze.crm_cust_info;

        BULK INSERT bronze.crm_cust_info
        FROM 'source_crm/cust_info.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"'
        );

        -- =========================================
        -- CRM PRODUCT INFORMATION
        -- =========================================

        PRINT 'Loading CRM Products';

        TRUNCATE TABLE bronze.crm_prd_info;

        BULK INSERT bronze.crm_prd_info
        FROM 'source_crm/prd_info.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"'
        );

        -- =========================================
        -- CRM SALES DETAILS
        -- =========================================

        PRINT 'Loading CRM Sales';

        TRUNCATE TABLE bronze.crm_sales_details;

        BULK INSERT bronze.crm_sales_details
        FROM 'source_crm/sales_details.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"'
        );

        -- =========================================
        -- ERP CUSTOMER DEMOGRAPHICS
        -- =========================================

        PRINT 'Loading ERP Customers';

        TRUNCATE TABLE bronze.erp_cust_az12;

        BULK INSERT bronze.erp_cust_az12
        FROM 'source_erp/CUST_AZ12.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"'
        );

        -- =========================================
        -- ERP CUSTOMER LOCATIONS
        -- =========================================

        PRINT 'Loading ERP Locations';

        TRUNCATE TABLE bronze.erp_loc_a101;

        BULK INSERT bronze.erp_loc_a101
        FROM 'source_erp/LOC_A101.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"'
        );

        -- =========================================
        -- ERP PRODUCT CATEGORIES
        -- =========================================

        PRINT 'Loading ERP Product Categories';

        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'source_erp/PX_CAT_G1V2.csv'
        WITH (
            DATA_SOURCE = 'RetailFlowBulkSource',
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            FIELDQUOTE = '"'
        );

        PRINT '=========================================';
        PRINT 'Bronze Layer Loading Completed';
        PRINT '=========================================';

        PRINT 'Total Duration (seconds): '
            + CAST(
                DATEDIFF(SECOND, @start_time, SYSDATETIME())
                AS VARCHAR(20)
              );

    END TRY

    BEGIN CATCH

        PRINT 'Bronze Layer Loading Failed';
        PRINT ERROR_MESSAGE();

        THROW;

    END CATCH
END;
GO
