-- Safe pre-approval reliability checks. No populated Silver TRUNCATE/INSERT.
:ON ERROR EXIT
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>'DataWarehouse' OR CONVERT(int,SERVERPROPERTY('EngineEdition'))<>3
 OR CONVERT(varchar(48),CONNECTIONPROPERTY('local_net_address'))<>'127.0.0.1'
 THROW 51400,'Expected local DataWarehouse loopback connection.',1;
DECLARE @machine sysname=CONVERT(sysname,SERVERPROPERTY('MachineName')),@rejected bit=0;
BEGIN TRY
 EXEC silver.refresh_all @expected_machine=@machine,@execute_refresh=1,@confirmation=NULL;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51303 THROW;
 SET @rejected=1;
END CATCH;
IF @rejected<>1 THROW 51401,'Missing-confirmation gate did not reject execution.',1;
IF @@TRANCOUNT<>0 THROW 51402,'Rejected call leaked a transaction.',1;
PRINT 'PASS: execution without confirmation is rejected before any Silver write.';

-- Demonstrates SQL Server TRUNCATE rollback semantics on a disposable session temp table.
-- This is NOT a substitute for the full-pipeline rollback test.
CREATE TABLE #rollback_probe(id int NOT NULL PRIMARY KEY,load_time datetime2 NOT NULL);
INSERT #rollback_probe VALUES(1,'2020-01-01'),(2,'2020-01-02');
BEGIN TRY
 BEGIN TRANSACTION;
 TRUNCATE TABLE #rollback_probe;
 INSERT #rollback_probe VALUES(99,SYSDATETIME());
 THROW 51403,'Deliberate temporary-table validation failure.',1;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 IF ERROR_NUMBER()<>51403 THROW;
END CATCH;
IF (SELECT COUNT(*) FROM #rollback_probe)<>2
 OR EXISTS(SELECT id,load_time FROM #rollback_probe EXCEPT SELECT id,load_time FROM
 (VALUES(1,CONVERT(datetime2,'2020-01-01')),(2,CONVERT(datetime2,'2020-01-02'))) expected(id,load_time))
 THROW 51404,'Temporary-table rollback did not restore rows/timestamps.',1;
PRINT 'PASS: disposable temp-table TRUNCATE/INSERT rolled back to exact original rows/timestamps.';
