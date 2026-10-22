
/*
=========================================================
 RetailFlow 360 | Advanced SQL Analytics
 Lesson 01: Change-over-Time Analysis
=========================================================
 Objectives:
 - Analyze sales performance over time.
 - Compare annual and monthly business measures.
 - Understand date granularity.
 - Practice YEAR, MONTH, DATETRUNC, and FORMAT.
 - Check missing dates before trend analysis.

 Data Source: gold.fact_sales
 Query Type: Read-only
=========================================================
*/

USE DataWarehouse;
GO

-- ======================================================
-- 1. DAILY SALES ANALYSIS
-- ======================================================
-- Business Question:
-- How much sales amount was recorded each day?
--
-- Granularity: One row per order date.
-- Exclude NULL dates because they cannot be placed
-- on a chronological timeline.

SELECT
    order_date,
    SUM(CAST(sales_amount AS DECIMAL(19,2)))
        AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY order_date
ORDER BY order_date;


-- ======================================================
-- 2. YEARLY SALES PERFORMANCE
-- ======================================================
-- Business Question:
-- How do sales, customers, orders, and quantities
-- change across calendar years?
--
-- YEAR extracts the year from order_date.
-- COUNT(DISTINCT customer_key) measures unique
-- purchasing customers active in each year.
-- It does NOT necessarily count new customers.

SELECT
    YEAR(order_date) AS order_year,
    SUM(CAST(sales_amount AS DECIMAL(19,2)))
        AS total_sales,
    COUNT(DISTINCT customer_key)
        AS purchasing_customers,
    COUNT(DISTINCT order_number)
        AS total_orders,
    SUM(CAST(quantity AS BIGINT))
        AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY order_year;

-- Business Question:
-- How do sales, quantities, and purchasing
-- customers change across calendar years?

SELECT
    YEAR(order_date) AS order_year,
    SUM(CAST(sales_amount AS DECIMAL(19,2)))
        AS total_sales,
    COUNT(DISTINCT customer_key)
        AS purchasing_customers,
    SUM(CAST(quantity AS BIGINT))
        AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY order_year;


-- ======================================================
-- 3. MONTH-OF-YEAR SALES ANALYSIS
-- ======================================================
-- Business Question:
-- Which calendar months account for the most sales?
--
-- MONTH extracts only the month number.
-- All Januaries from different years are grouped.
--
-- Important:
-- This is a pooled monthly total, not a true
-- month-by-month chronological time series.
-- Partial years can bias month comparisons.

SELECT
    MONTH(order_date) AS month_number,
    SUM(CAST(sales_amount AS DECIMAL(19,2)))
        AS total_sales,
    COUNT(DISTINCT order_number)
        AS total_orders
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY month_number;

-- Business Question:
-- Which calendar months generate the most
-- sales across all available years?

SELECT
    MONTH(order_date) AS order_month,
    SUM(CAST(sales_amount AS DECIMAL(19,2)))
        AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY order_month;

-- ======================================================
-- 4. MONTHLY SALES TREND USING DATETRUNC
-- ======================================================
-- Business Question:
-- How is sales performance changing each month?
--
-- DATETRUNC(MONTH, order_date) groups records
-- by calendar year and calendar month.
--
-- Example:
-- 2013-06-05 and 2013-06-25 become 2013-06-01.
--
-- This is the preferred query for plotting
-- a chronological monthly sales trend.

SELECT
    DATETRUNC(MONTH, order_date) AS sales_month,
    SUM(CAST(sales_amount AS DECIMAL(19,2)))
        AS total_sales,
    COUNT(DISTINCT customer_key)
        AS purchasing_customers,
    COUNT(DISTINCT order_number)
        AS total_orders,
    SUM(CAST(quantity AS BIGINT))
        AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY sales_month;

-- Business Question:
-- How does sales performance change
-- from one calendar month to the next?
--
-- DATETRUNC returns the beginning of each month
-- while preserving the year.

SELECT
    DATETRUNC(MONTH, order_date) AS sales_month,
    SUM(CAST(sales_amount AS DECIMAL(19,2)))
        AS total_sales,
    COUNT(DISTINCT order_number)
        AS total_orders,
    COUNT(DISTINCT customer_key)
        AS purchasing_customers,
    SUM(CAST(quantity AS BIGINT))
        AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY sales_month;

-- ======================================================
-- 5. FORMAT MONTHLY RESULTS FOR DISPLAY
-- ======================================================
-- Business Question:
-- How do we display months as 2013-Jan, 2013-Feb?
--
-- FORMAT creates a readable string label.
-- Always sort using the underlying sales_month date.

;WITH monthly_sales AS (
    SELECT
        DATETRUNC(MONTH, order_date) AS sales_month,
        SUM(CAST(sales_amount AS DECIMAL(19,2)))
            AS total_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
)
SELECT
    sales_month,
    FORMAT(sales_month, 'yyyy-MMM', 'en-US')
        AS month_label,
    total_sales
FROM monthly_sales
ORDER BY sales_month;


-- ======================================================
-- 6. DATE COMPLETENESS AND RECONCILIATION
-- ======================================================
-- Business Question:
-- How much sales data is excluded from date analysis?
--
-- Missing order dates cannot be allocated to a
-- month or year, so chronological totals may differ
-- from the overall KPI total.
--
-- Earlier validation reported 19 NULL order dates.
-- Recheck that observation using current data.

SELECT
    COUNT(*) AS total_sales_lines,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END)
        AS lines_missing_order_date,
    SUM(CAST(sales_amount AS DECIMAL(19,2)))
        AS overall_sales_amount,
    SUM(CASE
        WHEN order_date IS NOT NULL
        THEN CAST(sales_amount AS DECIMAL(19,2))
        ELSE 0
    END) AS sales_with_valid_order_date,
    SUM(CASE
        WHEN order_date IS NULL
        THEN CAST(sales_amount AS DECIMAL(19,2))
        ELSE 0
    END) AS sales_missing_order_date
FROM gold.fact_sales;
