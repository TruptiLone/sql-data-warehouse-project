
/*
=========================================================
 RetailFlow 360 | Advanced SQL Analytics
 Lesson 02: Cumulative Analysis
=========================================================
 Objectives:
 - Calculate cumulative sales across months.
 - Understand aggregate window functions.
 - Practice SUM() OVER() and PARTITION BY.
 - Compare running totals and moving averages.

 Data Source: gold.fact_sales
 Query Type: Read-only
=========================================================
*/

USE DataWarehouse;
GO

-- ======================================================
-- 1. MONTHLY SALES WITH RUNNING TOTAL
-- ======================================================
-- Business Question:
-- How much sales amount has accumulated over time?
--
-- Step 1: Aggregate sales at monthly granularity.
-- Step 2: Apply a window function to those totals.
--
-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
-- includes all previous months plus the current month.

;WITH monthly_sales AS (
    SELECT
        CAST(DATETRUNC(MONTH, order_date) AS DATE)
            AS sales_month,
        SUM(CAST(sales_amount AS DECIMAL(19,2)))
            AS total_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
)
SELECT
    sales_month,
    total_sales,
    SUM(total_sales) OVER (
        ORDER BY sales_month
        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW
    ) AS running_total_sales
FROM monthly_sales
ORDER BY sales_month;



-- ======================================================
-- 2. YEAR-TO-DATE RUNNING SALES
-- ======================================================
-- Business Question:
-- How much sales amount accumulates within each year?
--
-- PARTITION BY YEAR(sales_month) resets the
-- calculation at the beginning of each year.

;WITH monthly_sales AS (
    SELECT
        CAST(DATETRUNC(MONTH, order_date) AS DATE)
            AS sales_month,
        SUM(CAST(sales_amount AS DECIMAL(19,2)))
            AS total_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
)
SELECT
    sales_month,
    total_sales,
    SUM(total_sales) OVER (
        PARTITION BY YEAR(sales_month)
        ORDER BY sales_month
        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW
    ) AS yearly_running_sales
FROM monthly_sales
ORDER BY sales_month;



-- ======================================================
-- 3. MOVING AVERAGE AND CUMULATIVE AVERAGE
-- ======================================================
-- Business Questions:
-- What is the average sales amount over the current
-- and previous two available months?
--
-- How has the average of monthly unit prices
-- accumulated over time?

;WITH monthly_metrics AS (
    SELECT
        CAST(DATETRUNC(MONTH, order_date) AS DATE)
            AS sales_month,
        SUM(CAST(sales_amount AS DECIMAL(19,2)))
            AS total_sales,
        AVG(CAST(price AS DECIMAL(18,2)))
            AS average_unit_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
)
SELECT
    sales_month,
    total_sales,
    average_unit_price,

    -- Rolling average of the latest 3 monthly totals
    AVG(total_sales) OVER (
        ORDER BY sales_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS three_month_moving_average_sales,

    -- Expanding average of monthly average prices
    AVG(average_unit_price) OVER (
        ORDER BY sales_month
        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW
    ) AS cumulative_average_monthly_price

FROM monthly_metrics
ORDER BY sales_month;


