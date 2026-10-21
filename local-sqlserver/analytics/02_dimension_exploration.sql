
/*
=========================================================
 RetailFlow 360 | SQL Data Analytics
 Lesson 02: Dimension Exploration
=========================================================
 Objective:
 - Identify unique values within business dimensions.
 - Understand customer geographical distribution.
 - Explore product categories and their hierarchy.
 - Understand dimension cardinality and granularity.

 SQL Concepts: DISTINCT, ORDER BY
 Data Source: Gold Layer
=========================================================
*/

USE DataWarehouse;
GO

-- ======================================================
-- 1. CUSTOMER COUNTRY EXPLORATION
-- ======================================================
-- Business Question:
-- Which countries do our customers come from?
--
-- DISTINCT removes duplicate country values.
-- This helps identify the geographical coverage
-- of our customer base.
--
-- Observation:
-- Our current data contains six named countries
-- and an additional 'n/a' category for unknowns.
-- DISTINCT shows unique values, not customer counts.

SELECT DISTINCT
    country
FROM gold.dim_customers
ORDER BY country;


-- ======================================================
-- 2. PRODUCT CATEGORY EXPLORATION
-- ======================================================
-- Business Question:
-- What are the major product categories in our business?
--
-- DISTINCT identifies each unique product category.
-- Categories represent high-level product groupings.
--
-- Observation:
-- Our warehouse has four named categories:
-- Accessories, Bikes, Clothing, and Components.
-- NULL may also appear because some products have
-- unmatched ERP category mappings.
--
-- This helps us understand our product portfolio.

SELECT DISTINCT
    category
FROM gold.dim_products
ORDER BY category;


-- ======================================================
-- 3. PRODUCT HIERARCHY EXPLORATION
-- ======================================================
-- Business Question:
-- How are products organized into categories
-- and subcategories?
--
-- Hierarchy:
-- Category -> Subcategory -> Product Name
--
-- DISTINCT returns unique combinations of these
-- three columns, rather than unique values of
-- each column independently.
--
-- ORDER BY organizes the results hierarchically,
-- making the product structure easier to explore.
--
-- Key Insight:
-- Category has lower granularity than subcategory,
-- while product-level information provides more detail.
-- The number of unique combinations may differ from
-- the total number of product records.

SELECT DISTINCT
    category,
    subcategory,
    product_name
FROM gold.dim_products
ORDER BY
    category,
    subcategory,
    product_name;
