-- Execute via load_bronze.py, which supplies CSV-aware source counts.
-- Only the verified local Docker instance is supported. Existing rows are skipped.
:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF
    DB_NAME() <> N'DataWarehouse'
    OR CONVERT(int, SERVERPROPERTY('EngineEdition')) <> 3
    OR CONVERT(
        nvarchar(128), SERVERPROPERTY('Edition')
    ) NOT LIKE N'Developer Edition%'
    THROW 50300, 'Expected local Developer DataWarehouse.', 1;
DECLARE @rows bigint;
BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @rows = COUNT_BIG(*)
    FROM bronze.[crm_cust_info] WITH (TABLOCKX, HOLDLOCK);
    IF @rows > 0
        PRINT 'SKIPPED bronze.crm_cust_info: existing rows preserved.';
    ELSE
        BEGIN
            BULK INSERT bronze.[crm_cust_info]
            FROM '/var/opt/retailflow-datasets/.bulk/crm_cust_info.csv'
            WITH (
                FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"',
                FIELDTERMINATOR = ',',
                ROWTERMINATOR = '0x0a00',
                DATAFILETYPE = 'widechar',
                KEEPNULLS, TABLOCK, MAXERRORS = 0
            );
            SELECT @rows = COUNT_BIG(*) FROM bronze.[crm_cust_info];
            IF @rows <> $(crm_cust_info_rows)
                THROW 50301,
                'Source count mismatch: crm_cust_info; rolling back this load.',
                1;
            PRINT 'LOADED bronze.crm_cust_info: ' + CONVERT(varchar(20), @rows);
        END;

    SELECT @rows = COUNT_BIG(*)
    FROM bronze.[crm_prd_info] WITH (TABLOCKX, HOLDLOCK);
    IF @rows > 0
        PRINT 'SKIPPED bronze.crm_prd_info: existing rows preserved.';
    ELSE
        BEGIN
            BULK INSERT bronze.[crm_prd_info]
            FROM '/var/opt/retailflow-datasets/.bulk/crm_prd_info.csv'
            WITH (
                FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"',
                FIELDTERMINATOR = ',',
                ROWTERMINATOR = '0x0a00',
                DATAFILETYPE = 'widechar',
                KEEPNULLS, TABLOCK, MAXERRORS = 0
            );
            SELECT @rows = COUNT_BIG(*) FROM bronze.[crm_prd_info];
            IF @rows <> $(crm_prd_info_rows)
                THROW 50301,
                'Source count mismatch: crm_prd_info; rolling back this load.',
                1;
            PRINT 'LOADED bronze.crm_prd_info: ' + CONVERT(varchar(20), @rows);
        END;

    SELECT @rows = COUNT_BIG(*)
    FROM bronze.[crm_sales_details] WITH (TABLOCKX, HOLDLOCK);
    IF @rows > 0
        PRINT 'SKIPPED bronze.crm_sales_details: existing rows preserved.';
    ELSE
        BEGIN
            BULK INSERT bronze.[crm_sales_details]
            FROM '/var/opt/retailflow-datasets/.bulk/crm_sales_details.csv'
            WITH (
                FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"',
                FIELDTERMINATOR = ',',
                ROWTERMINATOR = '0x0a00',
                DATAFILETYPE = 'widechar',
                KEEPNULLS, TABLOCK, MAXERRORS = 0
            );
            SELECT @rows = COUNT_BIG(*) FROM bronze.[crm_sales_details];
            IF @rows <> $(crm_sales_details_rows)
                THROW 50301,
                'Source count mismatch: crm_sales_details; rolling back this load.',
                1;
            PRINT 'LOADED bronze.crm_sales_details: '
            + CONVERT(varchar(20), @rows);
        END;

    SELECT @rows = COUNT_BIG(*)
    FROM bronze.[erp_cust_az12] WITH (TABLOCKX, HOLDLOCK);
    IF @rows > 0
        PRINT 'SKIPPED bronze.erp_cust_az12: existing rows preserved.';
    ELSE
        BEGIN
            BULK INSERT bronze.[erp_cust_az12]
            FROM '/var/opt/retailflow-datasets/.bulk/erp_cust_az12.csv'
            WITH (
                FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"',
                FIELDTERMINATOR = ',',
                ROWTERMINATOR = '0x0a00',
                DATAFILETYPE = 'widechar',
                KEEPNULLS, TABLOCK, MAXERRORS = 0
            );
            SELECT @rows = COUNT_BIG(*) FROM bronze.[erp_cust_az12];
            IF @rows <> $(erp_cust_az12_rows)
                THROW 50301,
                'Source count mismatch: erp_cust_az12; rolling back this load.',
                1;
            PRINT 'LOADED bronze.erp_cust_az12: ' + CONVERT(varchar(20), @rows);
        END;

    SELECT @rows = COUNT_BIG(*)
    FROM bronze.[erp_loc_a101] WITH (TABLOCKX, HOLDLOCK);
    IF @rows > 0
        PRINT 'SKIPPED bronze.erp_loc_a101: existing rows preserved.';
    ELSE
        BEGIN
            BULK INSERT bronze.[erp_loc_a101]
            FROM '/var/opt/retailflow-datasets/.bulk/erp_loc_a101.csv'
            WITH (
                FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"',
                FIELDTERMINATOR = ',',
                ROWTERMINATOR = '0x0a00',
                DATAFILETYPE = 'widechar',
                KEEPNULLS, TABLOCK, MAXERRORS = 0
            );
            SELECT @rows = COUNT_BIG(*) FROM bronze.[erp_loc_a101];
            IF @rows <> $(erp_loc_a101_rows)
                THROW 50301,
                'Source count mismatch: erp_loc_a101; rolling back this load.',
                1;
            PRINT 'LOADED bronze.erp_loc_a101: ' + CONVERT(varchar(20), @rows);
        END;

    SELECT @rows = COUNT_BIG(*)
    FROM bronze.[erp_px_cat_g1v2] WITH (TABLOCKX, HOLDLOCK);
    IF @rows > 0
        PRINT 'SKIPPED bronze.erp_px_cat_g1v2: existing rows preserved.';
    ELSE
        BEGIN
            BULK INSERT bronze.[erp_px_cat_g1v2]
            FROM '/var/opt/retailflow-datasets/.bulk/erp_px_cat_g1v2.csv'
            WITH (
                FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"',
                FIELDTERMINATOR = ',',
                ROWTERMINATOR = '0x0a00',
                DATAFILETYPE = 'widechar',
                KEEPNULLS, TABLOCK, MAXERRORS = 0
            );
            SELECT @rows = COUNT_BIG(*) FROM bronze.[erp_px_cat_g1v2];
            IF @rows <> $(erp_px_cat_g1v2_rows)
                THROW 50301,
                'Source count mismatch: erp_px_cat_g1v2; rolling back this load.',
                1;
            PRINT 'LOADED bronze.erp_px_cat_g1v2: '
            + CONVERT(varchar(20), @rows);
        END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
