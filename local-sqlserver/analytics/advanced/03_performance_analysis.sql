
/*
=========================================================
 RetailFlow 360 | Advanced SQL Analytics
 Lesson 03: Performance Analysis
=========================================================

Business Requirement:
Analyze the yearly sales performance of products by
comparing current yearly sales against:

1. The product's average annual sales.
2. The same product's previous calendar-year sales.

Techniques:
- JOIN
- GROUP BY
- CTE
- AVG() OVER()
- LAG() OVER()
- CASE WHEN

Data source: gold.fact_sales, gold.dim_products
Query type: Read-only
=========================================================
*/

USE DataWarehouse;
GO

-- ======================================================
-- QUERY 1: YEARLY PRODUCT SALES
-- ======================================================
-- We group by product_key AND year.
-- This gives one row per product per year.
--
-- Use 2011-2013 for comparable complete calendar years.
-- 2010 and 2014 are partial years in our dataset.

SELECT
    YEAR(f.order_date) AS order_year,
    p.product_key,
    p.product_name,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2)))
        AS current_sales
FROM gold.fact_sales AS f
INNER JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
WHERE f.order_date >= '20110101'
  AND f.order_date < '20140101'
GROUP BY
    YEAR(f.order_date),
    p.product_key,
    p.product_name
ORDER BY
    p.product_name,
    p.product_key,
    order_year;

-- QUERY 2: SALES AGAINST EACH PRODUCT'S OBSERVED-YEAR AVERAGE
-- Question: Is this year's sales above or below the product's own benchmark?
-- Missing product-years are absent, not filled with zero. Products therefore
-- may have different numbers of observed years in their average.
;WITH yearly_sales AS (
    SELECT YEAR(f.order_date) AS order_year,
           p.product_key, p.product_name,
           SUM(CAST(f.sales_amount AS DECIMAL(19,2))) AS current_sales
    FROM gold.fact_sales AS f
    INNER JOIN gold.dim_products AS p ON f.product_key = p.product_key
    WHERE f.order_date >= '20110101' AND f.order_date < '20140101'
    GROUP BY YEAR(f.order_date), p.product_key, p.product_name
), benchmarks AS (
    SELECT *, AVG(current_sales) OVER (PARTITION BY product_key)
        AS average_annual_sales
    FROM yearly_sales
)
SELECT *, current_sales - average_annual_sales AS difference_vs_average,
    CASE WHEN current_sales > average_annual_sales THEN 'Above Average'
         WHEN current_sales < average_annual_sales THEN 'Below Average'
         ELSE 'At Average' END AS average_performance_status
FROM benchmarks
ORDER BY product_key, order_year;

-- QUERY 3: CALENDAR-YEAR-SAFE YEAR-OVER-YEAR PERFORMANCE
-- Question: How did sales change against the immediately preceding year?
-- LAG returns the previous available row; check its year before using it.
-- Missing comparisons produce NULL metrics, never a false 'No Change'.
-- A zero prior baseline yields a NULL percentage via NULLIF.
-- These appended queries were statically reviewed, not executed here.
;WITH yearly_sales AS (
    SELECT YEAR(f.order_date) AS order_year,
           p.product_key, p.product_name,
           SUM(CAST(f.sales_amount AS DECIMAL(19,2))) AS current_sales
    FROM gold.fact_sales AS f
    INNER JOIN gold.dim_products AS p ON f.product_key = p.product_key
    WHERE f.order_date >= '20110101' AND f.order_date < '20140101'
    GROUP BY YEAR(f.order_date), p.product_key, p.product_name
), prior_observations AS (
    SELECT *,
        LAG(order_year) OVER (PARTITION BY product_key ORDER BY order_year)
            AS previous_observed_year,
        LAG(current_sales) OVER (PARTITION BY product_key ORDER BY order_year)
            AS previous_observed_sales
    FROM yearly_sales
), comparisons AS (
    SELECT *,
        CASE WHEN previous_observed_year = order_year - 1
             THEN previous_observed_sales END AS previous_year_sales,
        CASE WHEN previous_observed_year = order_year - 1
             THEN current_sales - previous_observed_sales END AS year_over_year_difference,
        CASE WHEN previous_observed_year IS NULL THEN 'No Prior Year'
             WHEN previous_observed_year <> order_year - 1 THEN 'Missing Prior Calendar Year'
             WHEN current_sales > previous_observed_sales THEN 'Increase'
             WHEN current_sales < previous_observed_sales THEN 'Decrease'
             ELSE 'No Change' END AS year_over_year_status
    FROM prior_observations
)
SELECT *,
    CAST(100.0 * CAST(year_over_year_difference AS DECIMAL(19,2))
        / NULLIF(CAST(previous_year_sales AS DECIMAL(19,2)), 0)
        AS DECIMAL(19,6)) AS year_over_year_change_pct
FROM comparisons
ORDER BY product_key, order_year;

-- QUERY 4A: CONSECUTIVE-YEAR COMPARISON COUNTS
-- Question: How many comparable products improved, declined, or stayed flat?
-- Counts are per comparison year, not summed distinct products across years.
;WITH yearly_sales AS (
    SELECT YEAR(f.order_date) AS order_year,
           p.product_key, p.product_name,
           SUM(CAST(f.sales_amount AS DECIMAL(19,2))) AS current_sales
    FROM gold.fact_sales AS f
    INNER JOIN gold.dim_products AS p ON f.product_key = p.product_key
    WHERE f.order_date >= '20110101' AND f.order_date < '20140101'
    GROUP BY YEAR(f.order_date), p.product_key, p.product_name
), prior_observations AS (
    SELECT *,
        LAG(order_year) OVER (PARTITION BY product_key ORDER BY order_year)
            AS previous_observed_year,
        LAG(current_sales) OVER (PARTITION BY product_key ORDER BY order_year)
            AS previous_observed_sales
    FROM yearly_sales
), comparisons AS (
    SELECT *,
        CASE WHEN previous_observed_year = order_year - 1
             THEN previous_observed_sales END AS previous_year_sales,
        CASE WHEN previous_observed_year = order_year - 1
             THEN current_sales - previous_observed_sales END AS year_over_year_difference,
        CASE WHEN previous_observed_year IS NULL THEN 'No Prior Year'
             WHEN previous_observed_year <> order_year - 1 THEN 'Missing Prior Calendar Year'
             WHEN current_sales > previous_observed_sales THEN 'Increase'
             WHEN current_sales < previous_observed_sales THEN 'Decrease'
             ELSE 'No Change' END AS year_over_year_status
    FROM prior_observations
)
SELECT order_year, COUNT(*) AS comparable_products,
    SUM(CASE WHEN year_over_year_status = 'Increase' THEN 1 ELSE 0 END) AS increasing,
    SUM(CASE WHEN year_over_year_status = 'Decrease' THEN 1 ELSE 0 END) AS decreasing,
    SUM(CASE WHEN year_over_year_status = 'No Change' THEN 1 ELSE 0 END) AS unchanged
FROM comparisons
WHERE previous_observed_year = order_year - 1
GROUP BY order_year
ORDER BY order_year;

-- QUERY 4: TOP FIVE PRODUCTS BY ABSOLUTE YOY INCREASE IN 2013
-- Rank sales-amount differences, not percentage changes from tiny baselines.
;WITH yearly_sales AS (
    SELECT YEAR(f.order_date) AS order_year,
           p.product_key, p.product_name,
           SUM(CAST(f.sales_amount AS DECIMAL(19,2))) AS current_sales
    FROM gold.fact_sales AS f
    INNER JOIN gold.dim_products AS p ON f.product_key = p.product_key
    WHERE f.order_date >= '20110101' AND f.order_date < '20140101'
    GROUP BY YEAR(f.order_date), p.product_key, p.product_name
), prior_observations AS (
    SELECT *,
        LAG(order_year) OVER (PARTITION BY product_key ORDER BY order_year)
            AS previous_observed_year,
        LAG(current_sales) OVER (PARTITION BY product_key ORDER BY order_year)
            AS previous_observed_sales
    FROM yearly_sales
), comparisons AS (
    SELECT *,
        CASE WHEN previous_observed_year = order_year - 1
             THEN previous_observed_sales END AS previous_year_sales,
        CASE WHEN previous_observed_year = order_year - 1
             THEN current_sales - previous_observed_sales END AS year_over_year_difference,
        CASE WHEN previous_observed_year IS NULL THEN 'No Prior Year'
             WHEN previous_observed_year <> order_year - 1 THEN 'Missing Prior Calendar Year'
             WHEN current_sales > previous_observed_sales THEN 'Increase'
             WHEN current_sales < previous_observed_sales THEN 'Decrease'
             ELSE 'No Change' END AS year_over_year_status
    FROM prior_observations
)
SELECT TOP (5) product_key, product_name, previous_year_sales,
    current_sales, year_over_year_difference
FROM comparisons
WHERE order_year = 2013 AND previous_observed_year = 2012
  AND year_over_year_difference > 0
ORDER BY year_over_year_difference DESC, product_key;

-- QUERY 4: TOP FIVE PRODUCTS BY ABSOLUTE YOY DECREASE IN 2013
-- Rank sales-amount differences, not percentage changes from tiny baselines.
;WITH yearly_sales AS (
    SELECT YEAR(f.order_date) AS order_year,
           p.product_key, p.product_name,
           SUM(CAST(f.sales_amount AS DECIMAL(19,2))) AS current_sales
    FROM gold.fact_sales AS f
    INNER JOIN gold.dim_products AS p ON f.product_key = p.product_key
    WHERE f.order_date >= '20110101' AND f.order_date < '20140101'
    GROUP BY YEAR(f.order_date), p.product_key, p.product_name
), prior_observations AS (
    SELECT *,
        LAG(order_year) OVER (PARTITION BY product_key ORDER BY order_year)
            AS previous_observed_year,
        LAG(current_sales) OVER (PARTITION BY product_key ORDER BY order_year)
            AS previous_observed_sales
    FROM yearly_sales
), comparisons AS (
    SELECT *,
        CASE WHEN previous_observed_year = order_year - 1
             THEN previous_observed_sales END AS previous_year_sales,
        CASE WHEN previous_observed_year = order_year - 1
             THEN current_sales - previous_observed_sales END AS year_over_year_difference,
        CASE WHEN previous_observed_year IS NULL THEN 'No Prior Year'
             WHEN previous_observed_year <> order_year - 1 THEN 'Missing Prior Calendar Year'
             WHEN current_sales > previous_observed_sales THEN 'Increase'
             WHEN current_sales < previous_observed_sales THEN 'Decrease'
             ELSE 'No Change' END AS year_over_year_status
    FROM prior_observations
)
SELECT TOP (5) product_key, product_name, previous_year_sales,
    current_sales, year_over_year_difference
FROM comparisons
WHERE order_year = 2013 AND previous_observed_year = 2012
  AND year_over_year_difference < 0
ORDER BY year_over_year_difference ASC, product_key;
