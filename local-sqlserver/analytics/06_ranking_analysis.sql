
/*
=========================================================
 RetailFlow 360 | SQL Data Analytics
 Lesson 06: Ranking Analysis
=========================================================
 Objective:
 - Identify top and bottom performers.
 - Rank dimensions by aggregated business measures.
 - Practice TOP, ORDER BY, and GROUP BY.
 - Understand ROW_NUMBER, RANK, and DENSE_RANK.
 - Handle ties and distinguish customers from orders.

 Data Source: Gold Layer
 Query Type: Read-only
=========================================================
*/

USE DataWarehouse;
GO

-- ======================================================
-- 1. TOP 5 PRODUCTS BY TOTAL SALES
-- ======================================================
-- Business Question:
-- Which five current products generate the
-- highest total recorded sales amount?
--
-- Measure: SUM(sales_amount)
-- Dimension: Product
-- DESC: Highest sales first.
--
-- Group by product_key as well as product_name
-- to avoid combining distinct products with
-- identical names.

SELECT TOP (5)
    p.product_key,
    p.product_name,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2)))
        AS total_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY
    p.product_key,
    p.product_name
ORDER BY
    total_sales DESC,
    p.product_key;


-- ======================================================
-- 2. BOTTOM 5 PRODUCTS BY TOTAL SALES
-- ======================================================
-- Business Question:
-- Which five sold products generated the
-- lowest recorded sales amounts?
--
-- ASC sorts from lowest to highest.
--
-- Starting from fact_sales excludes products
-- that have no sales records. Those products
-- need a separate product-first LEFT JOIN.

SELECT TOP (5)
    p.product_key,
    p.product_name,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2)))
        AS total_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY
    p.product_key,
    p.product_name
ORDER BY
    total_sales ASC,
    p.product_key;


-- ======================================================
-- 3. TOP 5 PRODUCT SUBCATEGORIES BY SALES
-- ======================================================
-- Business Question:
-- Which subcategories generate the most sales?
--
-- Group by category and subcategory to keep
-- the business hierarchy visible.

SELECT TOP (5)
    p.category,
    p.subcategory,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2)))
        AS total_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY
    p.category,
    p.subcategory
ORDER BY
    total_sales DESC,
    p.category,
    p.subcategory;


-- ======================================================
-- 4. BOTTOM 5 PRODUCT SUBCATEGORIES BY SALES
-- ======================================================

SELECT TOP (5)
    p.category,
    p.subcategory,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2)))
        AS total_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY
    p.category,
    p.subcategory
ORDER BY
    total_sales ASC,
    p.category,
    p.subcategory;


-- ======================================================
-- 5. RANK PRODUCTS USING WINDOW FUNCTIONS
-- ======================================================
-- Business Question:
-- How do products rank according to total sales?
--
-- First calculate product-level sales with GROUP BY.
-- Next apply the three ranking window functions.
--
-- ROW_NUMBER: Unique sequential position.
-- RANK: Equal ranks for ties, with gaps afterward.
-- DENSE_RANK: Equal ranks for ties, without gaps.
--
-- The outer SELECT filters the top five positions.

;WITH product_sales AS (
    SELECT
        p.product_key,
        p.product_name,
        SUM(CAST(f.sales_amount AS DECIMAL(19,2)))
            AS total_sales
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    GROUP BY
        p.product_key,
        p.product_name
),
ranked_products AS (
    SELECT
        product_key,
        product_name,
        total_sales,
        ROW_NUMBER() OVER (
            ORDER BY total_sales DESC, product_key
        ) AS row_num,
        RANK() OVER (
            ORDER BY total_sales DESC
        ) AS sales_rank,
        DENSE_RANK() OVER (
            ORDER BY total_sales DESC
        ) AS dense_sales_rank
    FROM product_sales
)
SELECT *
FROM ranked_products
WHERE row_num <= 5
ORDER BY row_num;


-- ======================================================
-- 6. TOP 10 CUSTOMERS BY TOTAL SALES
-- ======================================================
-- Business Question:
-- Which customers contribute the most sales?
--
-- Customer key uniquely identifies each group.
-- Order count provides additional context.

SELECT TOP (10)
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2)))
        AS total_sales,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY
    total_sales DESC,
    c.customer_key;


-- ======================================================
-- 7. BOTTOM 3 PURCHASING CUSTOMERS BY ORDER COUNT
-- ======================================================
-- Business Question:
-- Which three purchasing customers placed
-- the fewest distinct orders?
--
-- COUNT(DISTINCT order_number) prevents
-- multiple sales lines from counting as
-- multiple orders.
--
-- Starting from fact_sales includes only
-- customers represented in the sales data.
-- Customers with zero purchases are excluded.

SELECT TOP (3)
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
WHERE f.customer_key IS NOT NULL
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY
    total_orders ASC,
    c.customer_key;
