# SQL Data Analytics — Lesson 05: Magnitude Analysis

These notes accompany the existing [Magnitude Analysis SQL](05_magnitude_analysis.sql). Result tables reproduce the project owner's supplied outputs from queries run in VS Code against the local `DataWarehouse`. They were not re-executed for this documentation task. Partial captures are explicitly labeled; omitted values are not estimated.

**Execution context:** The preserved SQL file starts with a country-count query before its `USE DataWarehouse; GO` block, then repeats that query in Section 1. Select `DataWarehouse` in the SQL client before running the entire file, or execute the context-setting block first. This avoids resolving the initial Gold reference in another database. The duplicate is harmless when the context is correct but produces an extra result set. No SQL implementation was changed.

## 1. What Is Magnitude Analysis?

Magnitude analysis compares aggregated business measures across dimensions. A useful conceptual formula is:

**Aggregate Function + Measure + GROUP BY Dimension = Business Insight**

For a record count, the measure is the number of records rather than a numeric column being summed. Examples in RetailFlow 360 include:

| Dimension | Aggregate measure | Business question |
|---|---|---|
| Country | Customer count | Where are registered customers located? |
| Gender | Customer count | How is recorded customer gender distributed? |
| Product category | Product count | How large is each current category? |
| Product category | Average cost | What is the average recorded current-product cost? |
| Product category | Sales amount | Which categories contribute sales? |
| Customer | Sales amount | Which customers have the highest recorded contributions? |
| Country | Quantity sold | Where are units purchased? |

**Measure Exploration** calculates overall totals, such as total sales across the sales fact. **Magnitude Analysis** breaks those measures down by a business dimension. A breakdown explains composition; it does not automatically establish trends over time, causation, or profitability.

## 2. Understanding GROUP BY

`GROUP BY` divides records into groups based on the selected dimension. Aggregate functions then summarize the records within each group.

Run the examples in the local `DataWarehouse` context:

```sql
USE DataWarehouse;
GO

SELECT
    country,
    COUNT(*) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;
```

| Clause | What it does |
|---|---|
| `SELECT country` | Displays the dimension value for each group |
| `COUNT(*) AS total_customers` | Counts every customer record in the group and names the result |
| `FROM gold.dim_customers` | Reads the integrated customer view |
| `GROUP BY country` | Forms one group for each country value, including a NULL group if present |
| `ORDER BY total_customers DESC` | Places the largest counts first |

`SELECT` expressions that are neither aggregated nor otherwise permitted constants must be represented in the grouping. `ORDER BY` improves readability by placing comparable magnitudes together; it does not change the counts. Without an explicit secondary sort, equal counts have no guaranteed relative order.

The text `'n/a'` is a stored category label, whereas SQL `NULL` represents absent information. Both should remain visible when assessing data quality.

## 3. Customer Distribution by Country

**Captured SQL results:**

| Country | Total Customers |
|---|---:|
| United States | 7,482 |
| Australia | 3,591 |
| United Kingdom | 1,913 |
| France | 1,810 |
| Germany | 1,780 |
| Canada | 1,571 |
| n/a | 337 |

The United States has the largest number of registered customer records, followed by Australia. The 337 `'n/a'` records have unknown country information and should not be silently discarded.

These counts describe registered customers, not necessarily purchasing activity by country. Customer geography is a dimension-level description; sales or unit comparisons require joining to the sales fact. The supplied country counts sum to **18,484**, matching the registered-customer total recorded in Lesson 04.

## 4. Customer Distribution by Gender

**Captured SQL results:**

| Gender | Total Customers |
|---|---:|
| Male | 9,341 |
| Female | 9,128 |
| n/a | 15 |

The recorded male and female customer counts are relatively close. Fifteen records have unknown gender information. These are stored classifications in the project data, not inferred identities or evidence about customer behavior.

```sql
SELECT
    gender,
    COUNT(*) AS total_customers
FROM gold.dim_customers
GROUP BY gender
ORDER BY total_customers DESC;
```

The counts sum to **18,484**. Retaining unknown labels makes the denominator and data-quality limitations explicit. Excluding them without explanation would change both the population represented and any percentages derived from it.

## 5. Product Distribution by Category

**Captured SQL results:**

| Category | Total Products |
|---|---:|
| Components | 127 |
| Bikes | 97 |
| Clothing | 35 |
| Accessories | 29 |
| NULL | 7 |

Components has the highest number of current products, and Bikes is the second-largest named category. The counts total **295**, reconciling to the current Gold product population.

The seven `NULL` category values represent missing category information, not a real category named “NULL.” The known CRM `CO_PE` versus ERP `CO_PD` category-code mismatch explains the unresolved mapping documented for seven current products. The current views preserve these products rather than silently dropping or relabeling them.

```sql
SELECT
    category,
    COUNT(*) AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;
```

`COUNT(*)` counts rows even in the NULL group. `COUNT(category)` would exclude NULL category values and return zero for that group, concealing its product-record count. This is a count of current catalog records, not products sold or historical product versions.

## 6. Average Product Cost by Category

**Partial captured result — Bikes is missing from the supplied output.**

| Category | Average Product Cost |
|---|---:|
| Components | 264.716535 |
| NULL | 28.571428 |
| Clothing | 24.800000 |
| Accessories | 13.172413 |

These are the exact copied values. This table is not the complete category result and does **not** establish that Components has the highest average cost overall. The Bikes value must be captured later; it is not inferred from prices, category sales, or the image.

```sql
SELECT
    category,
    AVG(CAST(cost AS DECIMAL(18,2))) AS average_product_cost
FROM gold.dim_products
GROUP BY category
ORDER BY average_product_cost DESC;
```

`AVG` calculates the arithmetic average of non-NULL product costs. Casting the input to decimal avoids integer-average truncation; SQL Server can return several decimal places. The dashboard displays two-decimal presentation values, while the table preserves the supplied precision. Recorded zero costs are included; SQL NULL costs are excluded. The project has documented cost-normalization assumptions, so a zero should not automatically be interpreted as a genuinely free product.

Average **cost** and average **selling price** are different measures. This calculation averages current product records, not sales lines or units sold. Current product cost is not necessarily the cost at the historical time of sale, so it cannot establish historical profit margins without further validation. Investigate the NULL category group separately rather than treating it as a named business segment. The currency is not established by these values.

## 7. Total Sales by Product Category

**Captured SQL results:**

| Product Category | Total Sales Amount |
|---|---:|
| Bikes | 28,316,272.00 |
| Accessories | 700,262.00 |
| Clothing | 339,716.00 |

Bikes contributes the largest recorded sales amount among the returned categories. Accessories and Clothing contribute smaller amounts. The supplied figures reconcile exactly:

**28,316,272.00 + 700,262.00 + 339,716.00 = 29,356,250.00**

This equals the overall sales total recorded in Measure Exploration. It is an arithmetic check of the supplied outputs, not a newly executed database reconciliation.

```sql
SELECT
    p.category,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2)))
        AS total_sales_amount
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_sales_amount DESC;
```

The fact supplies `sales_amount`, and the product dimension supplies `category`. `LEFT JOIN` retains every fact record even when no dimension row matches. Unmatched products and matched products with missing categories can both contribute to the NULL category group, so those situations need separate checks when diagnosing a result.

The dimension's `product_key` must be unique for a many-sales-lines-to-one-product join. If multiple dimension rows match one fact row, the join multiplies that row and can inflate totals. `LEFT JOIN` preserves unmatched rows; it does not itself guarantee one match per row.

Starting from the fact does not generate rows for catalog categories with no matching sales. The absence of Components or NULL from the captured output is not proof those categories are absent from the catalog. Avoid inventing a zero result or an explanation that has not been checked.

The monetary unit is **not verified as USD**. Product attributes come from the current product view, so category attribution should not be described as historically versioned “as of sale” classification.

## 8. Top 10 Customers by Total Sales

**Captured SQL results:**

| Customer Key | Customer Name | Total Sales | Orders |
|---|---|---:|---:|
| 1133 | Kaitlyn Henderson | 13,294.00 | 5 |
| 1302 | Nichole Nara | 13,294.00 | 5 |
| 1309 | Margaret He | 13,268.00 | 5 |
| 1132 | Randall Dominguez | 13,265.00 | 5 |
| 1301 | Adriana Gonzalez | 13,242.00 | 5 |
| 1322 | Rosa Hu | 13,215.00 | 5 |
| 1125 | Brandi Gill | 13,195.00 | 5 |
| 1308 | Brad She | 13,172.00 | 5 |
| 1297 | Francisco Sara | 13,164.00 | 5 |
| 434 | Maurice Shan | 12,914.00 | 6 |

```sql
SELECT TOP (10)
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2))) AS total_sales_amount,
    COUNT(DISTINCT f.order_number) AS total_orders
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
```

Grouping by `customer_key` and displaying the names measures individual customer contributions without combining different customers who share a name. Names are descriptive labels, not reliable unique identifiers. `COUNT(DISTINCT f.order_number)` counts unique non-NULL orders for each group instead of counting sales lines.

`ORDER BY` sorts total sales from highest to lowest; `TOP (10)` selects ten rows from that ordered result. Kaitlyn Henderson and Nichole Nara tie at 13,294.00. The secondary customer-key sort makes their order deterministic within the snapshot. This query returns ten rows, not all customers tied at the tenth-place value; including all boundary ties would require a different ranking policy.

If customer references are unmatched, grouping on the dimension-side key and names combines those unmatched facts into a NULL customer group. That is not an individual customer. Check missing references before interpreting the ranking; key uniqueness must also be validated to prevent duplicated sales totals.

Current Gold surrogate customer keys are computed with `ROW_NUMBER()` and can change when underlying data changes. They are useful within the queried model but should not be treated as permanent external identifiers.

These results could support later customer segmentation, purchase-frequency analysis, or customer-value modeling. They are recorded sales contributions within the available warehouse sales period, **not proven lifetime values** or forecasts. No particular monthly or annual period is implied by an unfiltered query.

## 9. Quantity Sold by Country

**Partial copied result — France, Germany, and any unknown-country grouping were omitted from the supplied capture.**

| Country | Total Units Sold |
|---|---:|
| United States | 20,481 |
| Australia | 13,346 |
| Canada | 7,630 |
| United Kingdom | 6,910 |

These values are not an exhaustive geographic distribution. The fact supplies quantity, and the customer dimension supplies country:

```sql
SELECT
    c.country,
    SUM(CAST(f.quantity AS BIGINT)) AS total_units_sold
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_units_sold DESC;
```

`SUM(quantity)` measures units, not sales amount, sales lines, or distinct orders. Casting to `BIGINT` before summing avoids an `INT` sum limit for larger datasets. Country is the customer dimension's recorded geography, not necessarily the shipment destination or customer's location at the time of every sale.

The four captured groups sum to **48,367** units. Compared with the recorded overall **60,423**, **12,056** units remain outside this partial capture. This is only a reconciliation residual calculated from supplied figures, not an allocation to any omitted country. Obtain the full result before creating a complete geographic comparison or assigning that residual to particular groups.

## 10. Low-Cardinality vs. High-Cardinality Dimensions

**Cardinality** is the number of distinct values in an attribute. In a grouped query, it helps explain how many result groups to expect.

| Relatively low cardinality | Higher cardinality |
|---|---|
| Country | Customer key |
| Gender | Product identifier |
| Product category | Order number |

Grouping by country produces relatively few rows because many customers share a country. Grouping by individual customer keys produces many rows because each key identifies a separate customer within the snapshot. Grouping by multiple attributes produces distinct combinations, so the result count depends on their relationships as well as individual cardinalities.

Low-cardinality dimensions often suit a simple comparison chart. High-cardinality dimensions may need Top-N tables, filters, pagination, or a clearly defined “Other” group for readability. A Top-N chart is not the full population; the display should say so. Cardinality and NULL/unknown handling should be explicit when designing a future dashboard.

## 11. Data Quality and Analytical Validation

The captured outputs and project context expose the following limitations:

| Observation | Interpretation / follow-up |
|---|---|
| 337 customers have `'n/a'` country | Keep unknown geography visible; investigate source completeness |
| 15 customers have `'n/a'` gender | Retain unknown classifications in denominators |
| Seven products have NULL category | Investigate the documented `CO_PE`/`CO_PD` mapping discrepancy without guessing a correction |
| Average-cost capture omits Bikes | Obtain the missing value before claiming an overall highest-cost category |
| Quantity-by-country capture is incomplete | Obtain all returned groups before claiming complete geographic coverage |

A `LEFT JOIN` does not prevent duplicated aggregates when dimension keys are nonunique. Reviewing the local view definitions shows the intended keys and relationships; that static review is not a new live uniqueness or completeness check. Recommended future validation should compare fact row counts before and after joins, test dimension-key uniqueness, and inspect unmatched or NULL fact references.

Arithmetic reconciliation of the supplied results gives:

| Breakdown | Sum of supplied groups | Comparison |
|---|---:|---|
| Registered customers by country | 18,484 | Matches Lesson 04 registered customers |
| Registered customers by gender | 18,484 | Matches Lesson 04 registered customers |
| Current products by category | 295 | Matches Lesson 04 current products |
| Sales amount by returned categories | 29,356,250.00 | Matches Lesson 04 total sales |
| Units by four captured countries | 48,367 | Partial: 12,056 below the 60,423 overall units |

Use the same snapshot, population, filters, and definitions when reconciling totals. Counts and sums can be added across complete nonoverlapping groups. Category averages cannot simply be added or averaged equally to recover an overall average; the non-NULL record counts that contributed to each average are needed as weights.

The existing SQL uses the expected Gold views, key-based joins, grouped aggregates, decimal-aware averages/sales totals, and distinct order counts. It is read-only. Its leading duplicate country query precedes the database-context statement; select `DataWarehouse` before executing the full file. The existing header's reference to business trends should not be interpreted as a verified historical trend: these queries compare aggregate magnitudes without a time grouping.

## 12. Magnitude Analysis Dashboard

![RetailFlow 360 Magnitude Analysis Board](images/retailflow_360_magnitude_analysis_board.png)

This is a **static graphical summary of the captured magnitude-analysis results**, copied from the supplied downloaded image without resizing or re-encoding. It is different from the earlier Measure Exploration KPI Board, which remains unchanged.

Important limitations apply to the image as well as the tables:

- The average-cost panel omits Bikes, and the country-quantity panel shows only four captured countries. Neither is a complete result listing.
- Cost figures are rounded to two decimals in the graphic; the notes preserve the supplied query precision.
- Decorative graphic elements do not represent verified historical trends.
- Dollar symbols in the generated design do not establish the source currency or verify USD.
- This is not a live BI dashboard, interactive application, or exhaustive view of every group.

The tables in these notes provide accessible text equivalents and explicitly identify partial captures. The absence of an image panel row should never be interpreted as a confirmed zero value.

## 13. Key Takeaways

| Concept | What this lesson demonstrates |
|---|---|
| `GROUP BY` | Organizes records into dimension groups |
| `SUM` | Totals recorded sales amounts or units within a group |
| `COUNT` | Counts records; distinct order counts prevent confusing lines with orders |
| `AVG` | Calculates arithmetic means with attention to numeric types and NULL inputs |
| `ORDER BY` | Makes comparisons readable and defines ranking order |
| `LEFT JOIN` | Preserves fact rows while adding dimension context; uniqueness still matters |
| `TOP (10)` | Limits an ordered result to leading rows under an explicit tie policy |
| Dimension cardinality | Guides the level of detail and presentation of grouped results |
| Fact/dimension relationships | Connect business measures to descriptive attributes through appropriate keys |
| Reconciliation and quality checks | Test whether breakdowns agree with overall totals and expose missing information |

Grouping measures by dimensions turns whole-warehouse totals into interpretable business comparisons. Reliable insights require correct grain, justified joins, complete captures, and a clear distinction between recorded results and assumptions.

## 14. Next Lesson

**Lesson 06 — Ranking Analysis** is upcoming. It will extend these concepts by identifying top and bottom performers using SQL ranking techniques and explicit handling of ties. Its results are not claimed as completed here.

After Magnitude Analysis and Ranking Analysis, an interactive business intelligence dashboard is planned. This documentation task does not implement that dashboard, an AI agent, or an automated refresh pipeline.

See the [analytics roadmap](README.md), [Measure Exploration notes](NOTES_MEASURE_EXPLORATION.md), and [Dimension Exploration notes](NOTES_DIMENSION_EXPLORATION.md) for related learning material.
