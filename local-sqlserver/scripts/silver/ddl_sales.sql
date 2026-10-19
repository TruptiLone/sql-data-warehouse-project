-- Local-only Silver sales DDL; preserve original column names/types.
:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 OR CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) NOT LIKE N'Developer Edition%'
 THROW 50801,'Expected local Developer DataWarehouse.',1;
IF SCHEMA_ID('silver') IS NULL THROW 50802,'Silver schema missing.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('silver.crm_sales_details') IS NOT NULL AND OBJECT_ID('silver.crm_sales_details','U') IS NULL
  THROW 50803,'Existing target is not a table; review required.',1;
 IF OBJECT_ID('silver.crm_sales_details','U') IS NULL
 BEGIN
 CREATE TABLE silver.crm_sales_details (
  sls_ord_num NVARCHAR(50) NULL,
  sls_prd_key NVARCHAR(50) NULL,
  sls_cust_id INT NULL,
  sls_order_dt DATE NULL,
  sls_ship_dt DATE NULL,
  sls_due_dt DATE NULL,
  sls_sales INT NULL,
  sls_quantity INT NULL,
  sls_price INT NULL,
  dwh_create_date DATETIME2 NULL DEFAULT GETDATE()
 );
 PRINT 'Created silver.crm_sales_details.';
 END;
DECLARE @expected TABLE(ordinal int,column_name sysname,type_name sysname,max_length smallint,scale tinyint);
INSERT @expected VALUES
(1,N'sls_ord_num',N'nvarchar',100,0),
(2,N'sls_prd_key',N'nvarchar',100,0),
(3,N'sls_cust_id',N'int',4,0),
(4,N'sls_order_dt',N'date',3,0),
(5,N'sls_ship_dt',N'date',3,0),
(6,N'sls_due_dt',N'date',3,0),
(7,N'sls_sales',N'int',4,0),
(8,N'sls_quantity',N'int',4,0),
(9,N'sls_price',N'int',4,0),
(10,N'dwh_create_date',N'datetime2',8,7);
IF EXISTS (
 SELECT ordinal,column_name,type_name,max_length,scale,1,0,0 FROM @expected EXCEPT
 SELECT column_id,name,TYPE_NAME(user_type_id),max_length,scale,CONVERT(int,is_nullable),CONVERT(int,is_identity),CONVERT(int,is_computed)
 FROM sys.columns WHERE object_id=OBJECT_ID('silver.crm_sales_details')
) OR EXISTS (
 SELECT column_id,name,TYPE_NAME(user_type_id),max_length,scale,CONVERT(int,is_nullable),CONVERT(int,is_identity),CONVERT(int,is_computed)
 FROM sys.columns WHERE object_id=OBJECT_ID('silver.crm_sales_details')
 EXCEPT SELECT ordinal,column_name,type_name,max_length,scale,1,0,0 FROM @expected
) THROW 50804,'Existing sales schema differs; no replacement allowed.',1;
COMMIT TRANSACTION;
PRINT 'PASS: all 10 Silver sales column definitions match original DDL.';
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
