:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 OR CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
 THROW 51201,'Expected local Developer DataWarehouse.',1;
IF SCHEMA_ID('silver') IS NULL THROW 51202,'Silver schema missing.',1;
BEGIN TRY
 BEGIN TRANSACTION;
IF OBJECT_ID('silver.erp_cust_az12') IS NOT NULL AND OBJECT_ID('silver.erp_cust_az12','U') IS NULL THROW 51203,'Target name conflict.',1;
IF OBJECT_ID('silver.erp_cust_az12','U') IS NULL
BEGIN
CREATE TABLE silver.erp_cust_az12(
 cid NVARCHAR(50) NULL,
 bdate DATE NULL,
 gen NVARCHAR(50) NULL,
 dwh_create_date DATETIME2 NULL DEFAULT GETDATE()
);
PRINT 'Created silver.erp_cust_az12';
END;
IF OBJECT_ID('silver.erp_loc_a101') IS NOT NULL AND OBJECT_ID('silver.erp_loc_a101','U') IS NULL THROW 51203,'Target name conflict.',1;
IF OBJECT_ID('silver.erp_loc_a101','U') IS NULL
BEGIN
CREATE TABLE silver.erp_loc_a101(
 cid NVARCHAR(50) NULL,
 cntry NVARCHAR(50) NULL,
 dwh_create_date DATETIME2 NULL DEFAULT GETDATE()
);
PRINT 'Created silver.erp_loc_a101';
END;
IF OBJECT_ID('silver.erp_px_cat_g1v2') IS NOT NULL AND OBJECT_ID('silver.erp_px_cat_g1v2','U') IS NULL THROW 51203,'Target name conflict.',1;
IF OBJECT_ID('silver.erp_px_cat_g1v2','U') IS NULL
BEGIN
CREATE TABLE silver.erp_px_cat_g1v2(
 id NVARCHAR(50) NULL,
 cat NVARCHAR(50) NULL,
 subcat NVARCHAR(50) NULL,
 maintenance NVARCHAR(50) NULL,
 dwh_create_date DATETIME2 NULL DEFAULT GETDATE()
);
PRINT 'Created silver.erp_px_cat_g1v2';
END;
DECLARE @spec TABLE(t sysname,n int,c sysname,typ sysname,bytes smallint,scale tinyint);
INSERT @spec VALUES
('erp_cust_az12',1,'cid','nvarchar',100,0),
('erp_cust_az12',2,'bdate','date',3,0),
('erp_cust_az12',3,'gen','nvarchar',100,0),
('erp_cust_az12',4,'dwh_create_date','datetime2',8,7),
('erp_loc_a101',1,'cid','nvarchar',100,0),
('erp_loc_a101',2,'cntry','nvarchar',100,0),
('erp_loc_a101',3,'dwh_create_date','datetime2',8,7),
('erp_px_cat_g1v2',1,'id','nvarchar',100,0),
('erp_px_cat_g1v2',2,'cat','nvarchar',100,0),
('erp_px_cat_g1v2',3,'subcat','nvarchar',100,0),
('erp_px_cat_g1v2',4,'maintenance','nvarchar',100,0),
('erp_px_cat_g1v2',5,'dwh_create_date','datetime2',8,7);
IF EXISTS(SELECT t.name,c.column_id,c.name,TYPE_NAME(c.user_type_id),c.max_length,c.scale,CONVERT(int,c.is_nullable),CONVERT(int,c.is_identity),CONVERT(int,c.is_computed)
FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id WHERE t.schema_id=SCHEMA_ID('silver') AND t.name IN (SELECT t FROM @spec) EXCEPT SELECT t,n,c,typ,bytes,scale,1,0,0 FROM @spec) OR EXISTS(SELECT t,n,c,typ,bytes,scale,1,0,0 FROM @spec EXCEPT SELECT t.name,c.column_id,c.name,TYPE_NAME(c.user_type_id),c.max_length,c.scale,CONVERT(int,c.is_nullable),CONVERT(int,c.is_identity),CONVERT(int,c.is_computed)
FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id WHERE t.schema_id=SCHEMA_ID('silver') AND t.name IN (SELECT t FROM @spec)) THROW 51204,'ERP schema mismatch; no replacement allowed.',1;
PRINT 'PASS: all 12 ERP column definitions match original Silver DDL.';
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
