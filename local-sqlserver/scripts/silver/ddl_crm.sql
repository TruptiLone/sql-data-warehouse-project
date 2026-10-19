-- Local-only, non-destructive DDL. Execute with sqlcmd -b in DataWarehouse.
:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition')) <> 3
 OR CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
 THROW 50500, 'Expected local Developer DataWarehouse.', 1;
IF SCHEMA_ID(N'silver') IS NULL THROW 50501, 'Silver schema missing.', 1;
BEGIN TRY
 BEGIN TRANSACTION;
IF OBJECT_ID(N'silver.crm_cust_info') IS NOT NULL AND OBJECT_ID(N'silver.crm_cust_info',N'U') IS NULL THROW 50502,'Target name is not a table.',1;
IF OBJECT_ID(N'silver.crm_cust_info',N'U') IS NULL
BEGIN
 CREATE TABLE silver.[crm_cust_info] (
  [cst_id] INT NULL,
  [cst_key] NVARCHAR(50) NULL,
  [cst_firstname] NVARCHAR(50) NULL,
  [cst_lastname] NVARCHAR(50) NULL,
  [cst_marital_status] NVARCHAR(50) NULL,
  [cst_gndr] NVARCHAR(50) NULL,
  [cst_create_date] DATE NULL,
  [dwh_create_date] DATETIME2 NULL DEFAULT GETDATE()
 );
 PRINT 'Created silver.crm_cust_info';
END;
IF OBJECT_ID(N'silver.crm_prd_info') IS NOT NULL AND OBJECT_ID(N'silver.crm_prd_info',N'U') IS NULL THROW 50502,'Target name is not a table.',1;
IF OBJECT_ID(N'silver.crm_prd_info',N'U') IS NULL
BEGIN
 CREATE TABLE silver.[crm_prd_info] (
  [prd_id] INT NULL,
  [cat_id] NVARCHAR(50) NULL,
  [prd_key] NVARCHAR(50) NULL,
  [prd_nm] NVARCHAR(50) NULL,
  [prd_cost] INT NULL,
  [prd_line] NVARCHAR(50) NULL,
  [prd_start_dt] DATE NULL,
  [prd_end_dt] DATE NULL,
  [dwh_create_date] DATETIME2 NULL DEFAULT GETDATE()
 );
 PRINT 'Created silver.crm_prd_info';
END;
DECLARE @spec TABLE(t sysname, n int, c sysname, typ sysname, bytes smallint);
INSERT @spec VALUES (N'crm_cust_info',1,N'cst_id',N'int',4),
(N'crm_cust_info',2,N'cst_key',N'nvarchar',100),
(N'crm_cust_info',3,N'cst_firstname',N'nvarchar',100),
(N'crm_cust_info',4,N'cst_lastname',N'nvarchar',100),
(N'crm_cust_info',5,N'cst_marital_status',N'nvarchar',100),
(N'crm_cust_info',6,N'cst_gndr',N'nvarchar',100),
(N'crm_cust_info',7,N'cst_create_date',N'date',3),
(N'crm_cust_info',8,N'dwh_create_date',N'datetime2',8),
(N'crm_prd_info',1,N'prd_id',N'int',4),
(N'crm_prd_info',2,N'cat_id',N'nvarchar',100),
(N'crm_prd_info',3,N'prd_key',N'nvarchar',100),
(N'crm_prd_info',4,N'prd_nm',N'nvarchar',100),
(N'crm_prd_info',5,N'prd_cost',N'int',4),
(N'crm_prd_info',6,N'prd_line',N'nvarchar',100),
(N'crm_prd_info',7,N'prd_start_dt',N'date',3),
(N'crm_prd_info',8,N'prd_end_dt',N'date',3),
(N'crm_prd_info',9,N'dwh_create_date',N'datetime2',8);
IF EXISTS (
 SELECT t,n,c,typ,bytes,1 FROM @spec EXCEPT
 SELECT t.name,c.column_id,c.name,TYPE_NAME(c.user_type_id),c.max_length,CONVERT(int,c.is_nullable)
 FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id
 WHERE t.schema_id=SCHEMA_ID('silver') AND t.name IN ('crm_cust_info','crm_prd_info')
) OR EXISTS (
 SELECT t.name,c.column_id,c.name,TYPE_NAME(c.user_type_id),c.max_length,CONVERT(int,c.is_nullable)
 FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id
 WHERE t.schema_id=SCHEMA_ID('silver') AND t.name IN ('crm_cust_info','crm_prd_info')
 EXCEPT SELECT t,n,c,typ,bytes,1 FROM @spec
) THROW 50503,'Existing Silver metadata does not match specification; no replacement allowed.',1;
COMMIT TRANSACTION;
PRINT 'Silver metadata: PASS (17 columns, original types and nullability).';
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
