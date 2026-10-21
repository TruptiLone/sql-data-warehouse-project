-- RetailFlow 360
-- Lesson 01: Database Exploration
-- Purpose: Explore database objects and metadata

USE DataWarehouse;
GO

-- 1. Explore all tables and views
SELECT *
FROM INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- 2. Explore columns
SELECT *
FROM INFORMATION_SCHEMA.COLUMNS

-- 3. Explore Gold customer columns
SELECT *
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold'
  AND TABLE_NAME = 'dim_customers'
ORDER BY ORDINAL_POSITION;

--What does this query do?
--INFORMATION_SCHEMA.TABLES gives us metadata about the tables and views available in our database.