# SQL Data Analytics — Lesson 04: Measure Exploration

These notes accompany [04 — Measure Exploration SQL](04_measure_exploration.sql). The seven KPI values are the project owner's recorded results from executing queries against the local `DataWarehouse` snapshot. They are not estimates, and no database queries or refreshes were executed to prepare this documentation. The previously validated sales-line count is identified separately below.

## 1. What Is Measure Exploration?

Measure exploration calculates high-level business metrics by applying aggregate functions to data. It establishes an overall picture of business activity before breaking results down by categories, regions, customers, or time periods.

A **dimension** describes or organizes business data; a **measure** quantifies it. A numeric identifier is not automatically a useful measure: adding customer keys, for example, has no business meaning.

| Dimensions | Measures and derived metrics |
|---|---|
| Country | Sales amount |
| Product category | Quantity sold |
| Customer | Total orders |
| Product name | Average selling price |
| Order date | Customer count |

Dimensions and measures work together. “Total sales” summarizes an amount across the dataset. “Total sales by product category” uses a dimension to form groups and calculates that measure for each group. The grouping and join keys must match the intended level of detail so that sales lines are not accidentally duplicated.

RetailFlow 360 exposes business-ready data through `gold.fact_sales`, `gold.dim_products`, and `gold.dim_customers`. These are SQL views, not physical Gold tables. Our baseline KPIs read those views without changing them.

## 2. SQL Aggregate Functions

| Function | Meaning | Important detail |
|---|---|---|
| `SUM(expression)` | Calculates a total | Ignores SQL `NULL` inputs |
| `AVG(expression)` | Calculates an arithmetic average | Ignores SQL `NULL`; the input type affects precision |
| `COUNT(*)` | Counts all records | Includes rows containing `NULL` values |
| `COUNT(column)` | Counts records with a non-NULL value in that column | Repeated non-NULL values each contribute |
| `COUNT(DISTINCT column)` | Counts unique non-NULL values | Repeats and SQL `NULL` do not contribute |
| `MIN(expression)` | Finds the smallest value | Useful for minimum prices or earliest dates; ignores `NULL` |
| `MAX(expression)` | Finds the largest value | Useful for maximum prices or latest dates; ignores `NULL` |

Without `GROUP BY`, aggregate functions calculate metrics across the entire selected dataset, after any `WHERE` filter. A query containing only aggregates normally produces one summary row. For an empty input, counts return zero, while `SUM`, `AVG`, `MIN`, and `MAX` return `NULL`.

Use the local warehouse context for the examples in this lesson:

```sql
USE DataWarehouse;
GO

SELECT
    SUM(CAST(sales_amount AS DECIMAL(19,2))) AS total_sales,
    AVG(CAST(price AS DECIMAL(18,2))) AS average_unit_price,
    MIN(price) AS minimum_unit_price,
    MAX(price) AS maximum_unit_price
FROM gold.fact_sales;
```

Casting `price` before `AVG` preserves a fractional average when the source is an integer. Casting only the final result would not recover a fraction already lost during aggregation.

```sql
SELECT
    COUNT(*) AS customer_records,
    COUNT(country) AS records_with_non_null_country,
    COUNT(DISTINCT country) AS distinct_non_null_countries
FROM gold.dim_customers;
```

A text label such as `'n/a'` is not SQL `NULL`; it is included in `COUNT(country)` and can contribute a distinct value. Do not interpret these counts as proof that all country labels are valid named countries.

SQL Server's `COUNT` returns `INT`. `COUNT_BIG` has the same counting purpose but returns `BIGINT`, making it preferable when row counts could exceed the `INT` range. The current project counts fit within that range; the existing lesson script therefore does not require a rewrite.

## 3. RetailFlow 360 Business Metrics

The following are the exact recorded results supplied for the current project snapshot:

| Business Metric | Value | Interpretation |
|---|---:|---|
| Total Sales | 29,356,250.00 | Sum of recorded sales amounts |
| Total Quantity Sold | 60,423 | Total units sold |
| Average Unit Price | 486.04 | Arithmetic mean of recorded sales-line unit prices |
| Total Unique Orders | 27,659 | Number of distinct non-NULL order numbers |
| Total Current Products | 295 | Current products in the Gold product dimension |
| Total Registered Customers | 18,484 | Customer records in the Gold customer dimension |
| Total Purchasing Customers | 18,484 | Distinct non-NULL customer keys in the sales fact |

Average unit price is **unweighted across sales lines**: each non-NULL recorded line price contributes once, regardless of the quantity purchased. The displayed value is rounded to two decimal places. It is not average order value, and it is not necessarily equal to total sales divided by total quantity.

A quantity-weighted average gives greater weight to lines with more units. For a defined set of non-NULL prices and quantities, its general calculation is `SUM(price * quantity) / SUM(quantity)`, with decimal arithmetic and protection against a zero denominator. It may differ from the arithmetic mean. Total sales divided by quantity is only equivalent when recorded sales amounts reconcile to price times quantity over the same included records. No weighted-average result is claimed here.

The Gold schema does not establish the currency of the recorded amounts. **USD is not verified.** Numeric SQL results are recorded separately from the image's dollar-sign presentation.

## 4. Understanding Sales Lines vs. Orders vs. Quantity

A **sales line** is one record representing a product line on an order. An **order** is a transaction identified by an order number and can contain multiple product lines. **Quantity** is the number of units purchased on a sales line.

This example is **illustrative**, not actual warehouse data:

| Order Number | Product | Quantity |
|---|---|---:|
| ORD-101 | Mountain Bike | 1 |
| ORD-101 | Helmet | 2 |
| ORD-101 | Gloves | 1 |
| ORD-102 | Road Bike | 3 |

The example has:

- **4 sales lines:** four rows.
- **2 unique orders:** ORD-101 and ORD-102.
- **7 units:** 1 + 2 + 1 + 3.

These concepts require different SQL calculations:

```sql
SELECT
    COUNT(*) AS total_sales_lines,
    COUNT(DISTINCT order_number) AS total_unique_orders,
    SUM(CAST(quantity AS BIGINT)) AS total_quantity
FROM gold.fact_sales;
```

Our previously validated sales fact contains **60,398 sales-line records**. The latest supplied query results report **27,659 unique orders** and **60,423 units sold**. Multiple product lines can belong to one order, and a line can contain multiple units, so these counts need not match. `COUNT(DISTINCT order_number)` excludes SQL `NULL` order numbers; a row count does not.

Understanding the fact view's grain prevents a common reporting error: calling every sales-line row an order or treating every row as one unit sold.

## 5. Registered Customers vs. Purchasing Customers

Registering a customer does not necessarily mean that the customer has placed an order. A customer dimension describes the available customer population; a sales fact records purchasing activity.

```sql
SELECT
    COUNT(*) AS registered_customers
FROM gold.dim_customers;

SELECT
    COUNT(DISTINCT customer_key) AS purchasing_customers
FROM gold.fact_sales;
```

The latest supplied output is **18,484 registered customers** and **18,484 purchasing customers**. These counts match in the current query result.

Equal counts alone do **not** prove every registered customer purchased. Two sets can have the same size while containing different members. Establishing full coverage also requires checking dimension-key uniqueness, matching fact keys to dimension keys, finding registered customers without matching sales, and investigating NULL or missing references.

Our Gold views use logical relationships rather than physical Gold foreign-key constraints. Historical relationship checks are useful context, but the equality of these two KPI counts is not a substitute for checks against the same snapshot. This lesson does not claim a verified 100% customer conversion rate, nor does it define a registration-to-purchase observation window.

## 6. Combining KPIs with UNION ALL

`UNION ALL` combines multiple `SELECT` result sets **vertically**. Each query contributes rows to the same output structure:

- `measure_name`: the label describing a metric.
- `measure_value`: its numerical result.

Each `SELECT` must return the same number of columns in the same positions, with compatible data types. The first `SELECT` supplies the output column names.

The following complete, read-only example produces our seven metrics. It uses wide aggregate inputs and a common decimal output type, preserving fractional averages and avoiding the usual `INT` aggregate limits:

```sql
USE DataWarehouse;
GO

SELECT
    'Total Sales' AS measure_name,
    CAST(SUM(CAST(sales_amount AS DECIMAL(19,2)))
         AS DECIMAL(38,2)) AS measure_value
FROM gold.fact_sales

UNION ALL

SELECT
    'Total Quantity',
    CAST(SUM(CAST(quantity AS BIGINT)) AS DECIMAL(38,2))
FROM gold.fact_sales

UNION ALL

SELECT
    'Average Unit Price',
    CAST(AVG(CAST(price AS DECIMAL(18,2))) AS DECIMAL(38,2))
FROM gold.fact_sales

UNION ALL

SELECT
    'Total Orders',
    CAST(COUNT_BIG(DISTINCT order_number) AS DECIMAL(38,2))
FROM gold.fact_sales

UNION ALL

SELECT
    'Total Current Products',
    CAST(COUNT_BIG(*) AS DECIMAL(38,2))
FROM gold.dim_products

UNION ALL

SELECT
    'Total Registered Customers',
    CAST(COUNT_BIG(*) AS DECIMAL(38,2))
FROM gold.dim_customers

UNION ALL

SELECT
    'Total Purchasing Customers',
    CAST(COUNT_BIG(DISTINCT customer_key) AS DECIMAL(38,2))
FROM gold.fact_sales
ORDER BY measure_name;
```

`SUM` over the decimal sales input returns a wider decimal result in SQL Server. Casting quantity to `BIGINT` **before** summing avoids an `INT` sum overflow; `COUNT_BIG` similarly avoids the `INT` count limit. The final `DECIMAL(38,2)` casts make the combined output consistent. These choices are appropriate for the current source ranges, although every numeric type still has a finite range. Integer-valued counts may display with `.00` in the combined report; that is formatting, not fractional customers or orders.

`UNION` removes duplicate result rows. `UNION ALL` preserves every row and avoids requesting duplicate elimination when each row is an intentionally labeled KPI. The final `ORDER BY` sorts the combined result by label; without it, the written order of the branches is not a guaranteed presentation order.

The existing SQL lesson uses `COUNT` and `DECIMAL(20,2)` outputs, which are sufficient for the recorded snapshot. It already casts prices before averaging and quantities before summing. It is preserved unchanged; the wider-type example above is an educational extension, not a claim that its working queries were incorrect.

## 7. Business Insights from Our SQL Results

The confirmed observations are the project owner's recorded SQL results:

- Total recorded sales amount is **29,356,250.00**.
- The warehouse reports **60,423 units sold**.
- Average recorded unit price is **486.04**, unweighted across sales lines.
- There are **27,659 unique non-NULL order numbers**.
- The current product catalog contains **295 products**.
- Registered-customer and purchasing-customer counts both equal **18,484** in this snapshot.

These figures establish the scale and composition of the dataset. They are a starting point for reconciliation and business reporting before category-level, geographic, or time-based analysis.

They do not, by themselves, prove growth, profitability, customer retention, or which product or country performs best. No date filter or reporting period is specified for these whole-view totals, so they should not be described as monthly or annual performance. The product count describes the **current** catalog, not every product version ever recorded. Possible explanations for business performance need further analysis rather than being inferred from decorative charts or overall totals.

## 8. KPI Dashboard

![RetailFlow 360 Analytics KPI Board](images/retailflow_360_kpi_board.png)

The board summarizes seven measures calculated from the Gold layer. It is a **static KPI snapshot**, not a live or automatically refreshed dashboard. Its values match the supplied SQL results.

The decorative mini-charts are **illustrative design elements**, not calculated time-series trends. The dollar signs are **unverified currency presentation** until the source currency is confirmed; they do not establish USD or any other currency.

The original downloaded PNG was copied without resizing or re-encoding. The numeric table in Section 3 provides a text alternative to the image and defines each measure precisely.

## 9. Key Takeaways

- Measures quantify business activity, while dimensions organize the context.
- Aggregate functions calculate high-level metrics across the selected data.
- `COUNT` and `COUNT(DISTINCT)` can produce different results because they count different things and handle NULL values differently.
- Understanding data granularity prevents misleading counts and duplicated measures.
- `SUM(quantity)` counts units, not sales lines or orders.
- Business KPIs provide a foundation for reporting and later grouped analyses.
- SQL analytics can support future dashboards and AI agents when metric definitions, data access, and interpretation are controlled. No live dashboard or AI agent is implemented by this lesson.

## 10. Next Lesson

**Lesson 05: Magnitude Analysis** will combine dimensions and measures to answer questions such as:

- Which countries generate the most sales?
- Which product categories generate the highest sales?
- How many customers belong to each country?
- Which categories contain the most products?

These analyses are upcoming, not completed results. Sales breakdowns will require appropriate joins and careful handling of missing dimension mappings so totals remain reconcilable.

Continue with the [analytics learning roadmap](README.md). Review [Database Fundamentals](NOTES_DATABASE_FOUNDATIONS.md) or [Dimension Exploration Notes](NOTES_DIMENSION_EXPLORATION.md) for the underlying concepts.
