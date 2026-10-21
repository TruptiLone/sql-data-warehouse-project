SELECT
    country,
    COUNT(*) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;



/*
=========================================================
 RetailFlow 360 | SQL Data Analytics
 Lesson 05: Magnitude Analysis
=========================================================
 Objective:
 - Compare business measures across dimensions.
 - Use GROUP BY with SUM, COUNT, and AVG.
 - Understand low- and high-cardinality dimensions.
 - Join Gold fact and dimension views.
 - Identify business trends and data-quality issues.

 Data Source: Gold Layer
 Query Type: Read-only
=========================================================
*/

USE DataWarehouse;
GO

-- ======================================================
-- 1. CUSTOMER DISTRIBUTION BY COUNTRY
-- ======================================================
-- Business Question:
-- Which countries have the most registered customers?
--
-- Dimension: country
-- Measure: COUNT(*) = total customer records
--
-- GROUP BY creates one group per country.
-- ORDER BY shows the largest groups first.
-- The 'n/a' category represents unknown locations.

SELECT
    country,
    COUNT(*) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;


-- ======================================================
-- 2. CUSTOMER DISTRIBUTION BY GENDER
-- ======================================================
-- Business Question:
-- How are registered customers distributed by gender?
--
-- Dimension: gender
-- Measure: total customer records
--
-- The result helps us understand the recorded
-- customer demographic distribution.

SELECT
    gender,
    COUNT(*) AS total_customers
FROM gold.dim_customers
GROUP BY gender
ORDER BY total_customers DESC;


-- ======================================================
-- 3. PRODUCT DISTRIBUTION BY CATEGORY
-- ======================================================
-- Business Question:
-- Which categories contain the most current products?
--
-- Dimension: category
-- Measure: number of current product records
--
-- NULL category values may reveal unresolved
-- product-category mapping issues.

SELECT
    category,
    COUNT(*) AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;


-- ======================================================
-- 4. AVERAGE PRODUCT COST BY CATEGORY
-- ======================================================
-- Business Question:
-- Which product categories have the highest average cost?
--
-- Dimension: category
-- Measure: AVG(cost)
--
-- DECIMAL avoids integer average truncation.
-- AVG ignores NULL costs but includes recorded zeros.
-- Cost is not necessarily the product's selling price.

SELECT
    category,
    AVG(CAST(cost AS DECIMAL(18,2)))
        AS average_product_cost
FROM gold.dim_products
GROUP BY category
ORDER BY average_product_cost DESC;


-- ======================================================
-- 5. TOTAL SALES BY PRODUCT CATEGORY
-- ======================================================
-- Business Question:
-- Which product categories generate the most sales?
--
-- Measure: sales_amount from fact_sales
-- Dimension: category from dim_products
--
-- LEFT JOIN preserves fact records that do not
-- match a product dimension row.
--
-- NULL categories should be investigated rather
-- than silently removed.

SELECT
    p.category,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2)))
        AS total_sales_amount
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_sales_amount DESC;


-- ======================================================
-- 6. TOP 10 CUSTOMERS BY TOTAL SALES
-- ======================================================
-- Business Question:
-- Which customers are associated with the highest
-- recorded sales amounts?
--
-- Measure: SUM(sales_amount)
-- Dimension: individual customer
--
-- GROUP BY customer_key prevents customers with
-- identical names from being combined.
-- COUNT(DISTINCT order_number) adds order context.
--
-- TOP (10) limits the output to the leading customers.

SELECT TOP (10)
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2)))
        AS total_sales_amount,
    COUNT(DISTINCT f.order_number)
        AS total_orders
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY
    total_sales_amount DESC,
    c.customer_key;


-- ======================================================
-- 7. TOTAL QUANTITY SOLD BY COUNTRY
-- Business Question:
-- Which countries account for the most units sold?
--
-- Measure: SUM(quantity)
-- Dimension: country from dim_customers
--
-- This measures units sold, not revenue.
-- LEFT JOIN preserves unmatched sales facts.

SELECT
    c.country,
    SUM(CAST(f.quantity AS BIGINT))
        AS total_units_sold
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_units_sold DESC;
