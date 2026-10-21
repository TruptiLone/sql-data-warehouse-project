
/*
=========================================================
 RetailFlow 360 | SQL Data Analytics
 Lesson 04: Measure Exploration
=========================================================
 Objective:
 - Calculate high-level business metrics.
 - Understand SUM, AVG, COUNT, and COUNT(DISTINCT).
 - Differentiate sales lines from unique orders.
 - Compare registered customers with purchasing customers.

 Data Source: Gold Layer
 Query Type: Read-only analytical queries
=========================================================
*/

USE DataWarehouse;
GO

-- ======================================================
-- 1. TOTAL SALES
-- ======================================================
-- Business Question:
-- What is the total sales amount generated?
--
-- SUM adds all sales_amount values.
-- Casting to DECIMAL supports larger totals.

SELECT
    SUM(CAST(sales_amount AS DECIMAL(19,2)))
        AS total_sales
FROM gold.fact_sales;


-- ======================================================
-- 2. TOTAL QUANTITY SOLD
-- ======================================================
-- Business Question:
-- How many individual items have been sold?
--
-- SUM(quantity) adds units sold, rather than
-- simply counting sales records.

SELECT
    SUM(CAST(quantity AS BIGINT)) AS total_quantity
FROM gold.fact_sales;


-- ======================================================
-- 3. AVERAGE SELLING PRICE
-- ======================================================
-- Business Question:
-- What is the average recorded unit price?
--
-- AVG calculates the arithmetic mean.
-- Convert price to DECIMAL to avoid integer
-- truncation in SQL Server.
--
-- This is an average across sales lines,
-- not a quantity-weighted average.

SELECT
    AVG(CAST(price AS DECIMAL(18,2)))
        AS average_selling_price
FROM gold.fact_sales;


-- ======================================================
-- 4. TOTAL NUMBER OF ORDERS
-- ======================================================
-- Business Question:
-- How many unique orders were placed?
--
-- COUNT(*) counts all sales line records.
-- COUNT(DISTINCT order_number) counts unique
-- non-NULL order numbers.
--
-- An order may contain multiple products, so
-- one order can generate multiple sales lines.

SELECT
    COUNT(*) AS total_sales_lines,
    COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales;


-- ======================================================
-- 5. TOTAL NUMBER OF PRODUCTS
-- ======================================================
-- Business Question:
-- How many current products are in our catalog?
--
-- Gold.dim_products contains current products.
-- COUNT(*) counts the product records.
-- COUNT(DISTINCT product_key) checks unique keys.

SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT product_key)
        AS unique_product_keys
FROM gold.dim_products;


-- ======================================================
-- 6. TOTAL REGISTERED CUSTOMERS
-- ======================================================
-- Business Question:
-- How many customer records are registered?
--
-- COUNT(*) counts all customer records.
-- COUNT(DISTINCT customer_key) checks unique keys.

SELECT
    COUNT(*) AS total_customers,
    COUNT(DISTINCT customer_key)
        AS unique_customer_keys
FROM gold.dim_customers;


-- ======================================================
-- 7. CUSTOMERS WHO PLACED ORDERS
-- ======================================================
-- Business Question:
-- How many unique customers have purchased?
--
-- The sales fact contains repeated customer keys
-- because one customer can have multiple orders.
--
-- DISTINCT ensures each non-NULL customer key
-- contributes only once to the result.

SELECT
    COUNT(DISTINCT customer_key)
        AS purchasing_customers
FROM gold.fact_sales;



-- ======================================================
-- 8. RETAILFLOW 360 | BUSINESS KPI SUMMARY
-- ======================================================
-- Business Question:
-- What are the most important overall business metrics?
--
-- UNION ALL combines multiple independent metrics
-- into a single two-column report.
--
-- Each SELECT returns:
--   measure_name  = Name of the business metric
--   measure_value = Calculated numerical result
--
-- DECIMAL casts ensure compatible measure types.

SELECT
    'Total Sales' AS measure_name,
    CAST(
        SUM(CAST(sales_amount AS DECIMAL(19,2)))
        AS DECIMAL(20,2)
    ) AS measure_value
FROM gold.fact_sales

UNION ALL

SELECT
    'Total Quantity',
    CAST(SUM(CAST(quantity AS BIGINT)) AS DECIMAL(20,2))
FROM gold.fact_sales

UNION ALL

SELECT
    'Average Unit Price',
    CAST(AVG(CAST(price AS DECIMAL(18,2)))
         AS DECIMAL(20,2))
FROM gold.fact_sales

UNION ALL

SELECT
    'Total Orders',
    CAST(COUNT(DISTINCT order_number) AS DECIMAL(20,2))
FROM gold.fact_sales

UNION ALL

SELECT
    'Total Current Products',
    CAST(COUNT(*) AS DECIMAL(20,2))
FROM gold.dim_products

UNION ALL

SELECT
    'Total Registered Customers',
    CAST(COUNT(*) AS DECIMAL(20,2))
FROM gold.dim_customers

UNION ALL

SELECT
    'Total Purchasing Customers',
    CAST(COUNT(DISTINCT customer_key) AS DECIMAL(20,2))
FROM gold.fact_sales;
