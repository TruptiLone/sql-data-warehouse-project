
-- ==================================================
-- Bronze Layer: First CSV Import
-- Source: Azure Blob Storage
-- Destination: bronze.crm_cust_info
-- ==================================================

BULK INSERT bronze.crm_cust_info
FROM 'source_crm/cust_info.csv'
WITH (
    DATA_SOURCE = 'RetailFlowBlobSource',
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    FIELDQUOTE = '"'
);
GO
