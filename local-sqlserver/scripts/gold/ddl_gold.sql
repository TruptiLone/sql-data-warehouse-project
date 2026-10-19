-- Prepared only. Run from repository root via verified local SQLCMD with -b.
-- Review existing view definitions before altering. No DROP or physical tables.
:ON ERROR EXIT
USE [DataWarehouse];
GO
IF EXISTS(SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID('gold')
 AND name IN('dim_customers','dim_products','fact_sales') AND type<>'V')
 THROW 51801,'Non-view Gold naming conflict; stop for approval.',1;
GO
:r local-sqlserver/scripts/gold/view_customers.sql
:r local-sqlserver/scripts/gold/view_products.sql
:r local-sqlserver/scripts/gold/view_sales.sql
