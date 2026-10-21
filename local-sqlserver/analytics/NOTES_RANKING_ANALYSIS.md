# SQL Data Analytics — Lesson 06: Ranking Analysis

These notes accompany the preserved [Ranking Analysis SQL](06_ranking_analysis.sql). Tables labeled **captured results** reproduce the project owner's supplied outputs from local SQL execution. They are not new database measurements. Examples labeled illustrative explain concepts rather than warehouse records. No SQL was executed while preparing these notes.

## 1. What Is Ranking Analysis?

Ranking analysis orders dimension values according to aggregated measures to identify top and bottom performers.

**Dimension + Aggregated Measure + ORDER BY + TOP/Ranking Function = Ranked Business Insight**

Examples include the top five products by sales, bottom five sold products by sales, leading product subcategories, customers with the highest recorded purchases, and purchasing customers with the fewest distinct orders.

Magnitude Analysis compares measures across dimension groups. Ranking Analysis orders those groups and focuses attention on the highest or lowest values. A ranking is only meaningful with a defined measure, population, time scope, and tie policy. High sales alone do not establish profit, and a low sales rank is not a recommendation to discontinue a product.

## 2. SQL Concepts Used

| Concept | Role in RetailFlow 360 |
|---|---|
| `TOP (N)` | Limits the output to N rows, unless an explicit tie policy includes more |
| `ORDER BY ... DESC` | Places the highest sales totals first |
| `ORDER BY ... ASC` | Places the lowest sales totals or order counts first |
| `GROUP BY` | Aggregates sales lines into product, subcategory, or customer groups |
| `SUM()` | Totals recorded sales amounts for a group |
| `COUNT(DISTINCT order_number)` | Counts unique non-NULL orders rather than sales lines |
| `LEFT JOIN` | Adds descriptive dimension attributes while retaining unmatched fact rows |
| `ROW_NUMBER()` | Assigns unique sequential positions |
| `RANK()` | Gives ties equal ranks and leaves gaps after ties |
| `DENSE_RANK()` | Gives ties equal ranks without gaps |

SQL Server uses `SELECT TOP (5)` to request five rows. `ORDER BY total_sales DESC` defines which five are selected; `TOP` without a suitable order does not mean the best five. The aggregate is calculated at the chosen group grain before the groups are sorted and limited.

A simple counting example is:

```sql
USE DataWarehouse;
GO

SELECT TOP (3)
    customer_key,
    COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales
WHERE customer_key IS NOT NULL
GROUP BY customer_key
ORDER BY total_orders ASC, customer_key;
```

This selects three fact-side customer-key groups with the smallest distinct order counts. It illustrates counting and sorting; the existing lesson additionally joins customer names. A second sort key makes a selection reproducible within a snapshot when measures tie.

`SUM(CAST(sales_amount AS DECIMAL(19,2)))` preserves decimal arithmetic and widens the aggregate compared with summing an integer column. `COUNT` is sufficient for current recorded counts; larger populations may require `COUNT_BIG`. NULL order numbers do not contribute to distinct order counts.

## 3. Top 5 Products by Total Sales

**Captured results:**

| Product Key | Product Name | Total Sales |
|---|---|---:|
| 122 | Mountain-200 Black- 46 | 1,373,454.00 |
| 121 | Mountain-200 Black- 42 | 1,363,128.00 |
| 123 | Mountain-200 Silver- 38 | 1,339,394.00 |
| 125 | Mountain-200 Silver- 46 | 1,301,029.00 |
| 120 | Mountain-200 Black- 38 | 1,294,854.00 |

Mountain-200 Black- 46 is the highest-sales individual product in the returned results at 1,373,454.00. All five leaders are Mountain-200 variants. Their size/color variants remain separate products when calculating sales; they are not merged into one generic Mountain-200 name.

Grouping by `product_key` as well as `product_name` avoids combining distinct products with identical descriptive names. These figures are recorded sales in the current Gold model, not profit or forecasts.

```sql
SELECT TOP (5)
    p.product_key,
    p.product_name,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2))) AS total_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.product_key, p.product_name
ORDER BY total_sales DESC, p.product_key;
```

Run subsequent examples in `DataWarehouse`, selected above. The product key is a snapshot grouping key, not a permanently allocated external identifier.

## 4. Bottom 5 Products by Total Sales

**Captured results:**

| Product Key | Product Name | Total Sales |
|---|---|---:|
| 279 | Racing Socks- L | 2,430.00 |
| 280 | Racing Socks- M | 2,682.00 |
| 259 | Patch Kit/8 Patches | 6,382.00 |
| 168 | Bike Wash - Dissolver | 7,272.00 |
| 291 | Touring Tire Tube | 7,440.00 |

Racing Socks- L has the lowest recorded sales among the returned sold products. Ascending order selects the smallest totals:

```sql
SELECT TOP (5)
    p.product_key,
    p.product_name,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2))) AS total_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.product_key, p.product_name
ORDER BY total_sales ASC, p.product_key;
```

Starting from `gold.fact_sales` ranks only products represented in sales. Unsold catalog products are not included. A separate product-dimension-first analysis would be needed to include them.

Low sales do not necessarily mean low profitability or poor business value. Price, margins, availability, inventory exposure, and complementary purchases could matter. Those explanations require further evidence and are not established by this ranking.

## 5. Top 5 Product Subcategories by Sales

**Captured results:**

| Category | Subcategory | Total Sales |
|---|---|---:|
| Bikes | Road Bikes | 14,519,438.00 |
| Bikes | Mountain Bikes | 9,952,254.00 |
| Bikes | Touring Bikes | 3,844,580.00 |
| Accessories | Tires and Tubes | 244,634.00 |
| Accessories | Helmets | 225,435.00 |

**Road Bikes leads with 14,519,438.00.** Mountain Bikes ranks second and Touring Bikes third. All three belong to the Bikes category.

The hierarchy is **Category → Subcategory → Product**. The highest individual product can be a Mountain-200 variant while Road Bikes has the largest subcategory total, because a subcategory combines sales across many products. These are different grouping grains and answer different business questions.

```sql
SELECT TOP (5)
    p.category,
    p.subcategory,
    SUM(CAST(f.sales_amount AS DECIMAL(19,2))) AS total_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.category, p.subcategory
ORDER BY total_sales DESC, p.category, p.subcategory;
```

Grouping by both category and subcategory preserves the hierarchy and avoids combining equally named subcategories from different categories.

## 6. Bottom 5 Product Subcategories by Sales

**Captured results:**

| Category | Subcategory | Total Sales |
|---|---|---:|
| Clothing | Socks | 5,112.00 |
| Accessories | Cleaners | 7,272.00 |
| Clothing | Caps | 19,710.00 |
| Clothing | Gloves | 34,320.00 |
| Clothing | Vests | 36,160.00 |

Socks has the lowest recorded sales among the returned subcategories. Four of the five groups belong to Clothing; Cleaners belongs to Accessories. The existing SQL uses the same category/subcategory grouping as the top query with ascending total sales.

Lower sales alone do not determine profitability, demand potential, or strategic value. Inventory cost, margins, product availability, and purchase frequency are possible future analyses, not conclusions from this table. Like the bottom-product query, this fact-first query does not automatically include unsold catalog subcategories.

## 7. Ranking Products Using Window Functions

**Captured query results:**

| Product Key | Product Name | Total Sales | ROW_NUMBER | RANK | DENSE_RANK |
|---|---|---:|---:|---:|---:|
| 122 | Mountain-200 Black- 46 | 1,373,454.00 | 1 | 1 | 1 |
| 121 | Mountain-200 Black- 42 | 1,363,128.00 | 2 | 2 | 2 |
| 123 | Mountain-200 Silver- 38 | 1,339,394.00 | 3 | 3 | 3 |
| 125 | Mountain-200 Silver- 46 | 1,301,029.00 | 4 | 4 | 4 |
| 120 | Mountain-200 Black- 38 | 1,294,854.00 | 5 | 5 | 5 |

All three functions return 1 through 5 here because these leading sales totals are distinct. The following **illustrative tie example is not warehouse data**:

| Product | Sales | ROW_NUMBER | RANK | DENSE_RANK |
|---|---:|---:|---:|---:|
| A | 1000 | 1 | 1 | 1 |
| B | 800 | 2 | 2 | 2 |
| C | 800 | 3 | 2 | 2 |
| D | 600 | 4 | 4 | 3 |

- Product A leads alone, so all functions assign 1.
- B receives sequential position 2 and sales rank 2.
- C ties B at 800. `ROW_NUMBER` still assigns a new position, 3; `RANK` and `DENSE_RANK` both retain rank 2.
- D is the fourth row. `RANK` assigns 4 because two rows occupied rank 2, while `DENSE_RANK` assigns 3 because 600 is the third distinct sales total.

For reproducible B/C positions, `ROW_NUMBER` needs a unique tie-breaker such as product key. The sales-based `RANK` and `DENSE_RANK` should order by sales alone when equal sales must remain tied. Adding a unique key inside those functions' ordering would break the sales ties.

Aggregate first, rank the grouped results second, then filter in an outer query:

```sql
;WITH product_sales AS (
    SELECT
        p.product_key,
        p.product_name,
        SUM(CAST(f.sales_amount AS DECIMAL(19,2))) AS total_sales
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    GROUP BY p.product_key, p.product_name
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
```

A common table expression (CTE) names a query result for use by the following statement; it does not create a physical table. The leading semicolon safely terminates a preceding statement.

In SQL's logical processing order, the same query block's `WHERE` is evaluated before its window-function results are available. The outer query can filter the ranking columns calculated in the CTE. `row_num <= 5` selects five positions; filtering a sales rank instead can include more rows when ties occur. The final `ORDER BY` controls display order independently of each window's calculation order.

## 8. Top 10 Customers by Total Sales

**Captured results:**

| Customer Key | Customer Name | Total Sales | Total Orders |
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

Kaitlyn Henderson and Nichole Nara tie at 13,294.00. Their order within the top ten depends on tie-breaking logic; the existing query orders by total sales descending and then customer key ascending. Most listed customers have five distinct orders. Maurice Shan has six but lower total sales than the customers above him, illustrating that frequency and spending are different measures of purchasing behavior.

The existing query groups by `customer_key`, `first_name`, and `last_name`, sums recorded sales, and counts distinct order numbers. The key prevents different customers who share names from being merged. Names are descriptive attributes rather than reliable unique identifiers.

Gold customer keys are generated dynamically by a view using `ROW_NUMBER()`. They can change after future data changes and are not permanently allocated customer identifiers. These sales totals cover the available warehouse sales population; they are not established lifetime values, loyalty scores, or predictions.

## 9. Bottom 3 Purchasing Customers by Order Count

**Captured results:**

| Customer Key | Customer Name | Total Orders |
|---|---|---:|
| 16 | Chloe Young | 1 |
| 17 | Wyatt Hill | 1 |
| 21 | Jordan King | 1 |

All three returned customers have one distinct order. They are three examples tied for the fewest orders among purchasing customers, not necessarily the only three people with one order.

The existing query starts from the sales fact, excludes NULL fact customer keys, groups by dimension customer key and names, then sorts by order count ascending and customer key ascending. `TOP (3)` limits the displayed rows, and the secondary sort determines which three tied keys appear. Customers without fact records are excluded.

**Bonus: finding registered customers with no purchases.** Reverse the starting population to the customer dimension:

```sql
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.dim_customers AS c
LEFT JOIN gold.fact_sales AS f
    ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
HAVING COUNT(DISTINCT f.order_number) = 0
ORDER BY c.customer_key;
```

`HAVING` filters aggregated groups. This is an educational example, not an executed result or a claim that such customers exist. With valid non-NULL order numbers, it can identify customers with no recorded orders. If matched sales rows have only NULL order numbers, they also satisfy this condition; verify order-number completeness or separately check for absence of fact matches before calling them non-purchasers.

## 10. TOP vs. Window Functions

| Technique | Best Use Case |
|---|---|
| TOP (N) | Simple highest/lowest N queries |
| TOP (N) WITH TIES | Include rows tied at the cutoff |
| ROW_NUMBER | Unique ordering and pagination |
| RANK | Competition-style ranking with gaps |
| DENSE_RANK | Ranking without gaps |
| CTE + Window Function | Multi-stage ranking and more complex queries |

Tie policy affects both membership and row count:

- `TOP (5)` returns at most five rows; add deterministic secondary sorting to control tied selections.
- `TOP (5) WITH TIES` can return more than five rows when rows tie on **all ORDER BY expressions** at the cutoff. For sales ties, order by sales alone at that selection stage; including a unique key there prevents those rows from tying. Presentation ordering can be added in an outer query.
- `ROW_NUMBER() <= 5` selects five sequential positions when at least five groups exist.
- `RANK() <= 5` includes rows whose competition rank is at most five, with gaps after ties.
- `DENSE_RANK() <= 5` includes the top five distinct measure values and can return many more than five rows.

Use `TOP` for a simple result limit. Use window functions when you need explicit rank columns, ranking within groups, pagination, or multi-stage filtering. Match the method to the business question rather than treating the techniques as interchangeable.

## 11. Business Insights

Direct observations from the supplied query outputs are:

- Mountain-200 Black- 46 leads individual product sales at 1,373,454.00.
- Racing Socks- L has the lowest sales among the returned sold products at 2,430.00.
- Road Bikes leads subcategory sales at 14,519,438.00; Mountain Bikes is second.
- Socks is the lowest-sales subcategory in the returned ranking at 5,112.00.
- Kaitlyn Henderson and Nichole Nara tie for the highest customer sales among the returned results at 13,294.00.
- Chloe Young, Wyatt Hill, and Jordan King each have one order and appear in the bottom-three result.

These observations identify candidates for further investigation. They do not prove product profitability, customer loyalty, future demand, or long-term trends. No reporting-period filter is specified in these queries, so the results should not be labeled monthly or annual performance without additional context.

## 12. Data Model and Quality Considerations

- **Current product attribution:** Product rankings use the current Gold product dimension. The model does not provide full historical, as-of-sale product attribution.
- **Dynamic keys:** Gold surrogate keys are calculated in views and can change when underlying data changes; avoid using them as permanently stable external IDs.
- **Join cardinality:** A fact-first `LEFT JOIN` preserves unmatched facts, but nonunique dimension keys can multiply a fact row and inflate sales aggregates. Check key uniqueness and row-count/total reconciliation on the same snapshot.
- **NULL references:** Monitor NULL and unmatched product/customer references. Grouping by dimension-side keys can merge unmatched facts into a NULL group rather than an individual entity. The bottom-customer query excludes NULL fact keys, but that does not independently exclude non-NULL keys with no dimension match.
- **Population:** Fact-first bottom rankings exclude unsold catalog products and customers without sales records. Missing groups are not automatically zero-valued groups.
- **Ties:** Specify whether a report selects N rows or all rows tied at a measure cutoff.
- **Currency:** No source currency is confirmed. Sales amounts must not be described as verified USD, regardless of generated image formatting.

Static review found the expected Gold references, key-based joins, decimal sales sums, distinct order counts, valid CTE structure, and appropriate window ordering. The existing SQL is read-only and was preserved without changes. No live uniqueness, relationship, or query-result checks were performed in this documentation task.

## 13. Ranking Analysis Dashboard

![RetailFlow 360 Ranking Analysis Board](images/retailflow_360_ranking_analysis_board.png)

This static ranking dashboard summarizes product, subcategory, and customer performance using aggregated SQL queries against RetailFlow 360 Gold-layer views.

It is a portfolio visualization of query results, not an automatically refreshed analytical application. Decorative mini-bars and graphics are not verified time-series trends. The numerical result tables in these notes provide text equivalents for interpreting the image.

The supplied PNG was visually checked: its corrected takeaway says **Mountain-200 leads products; Road Bikes leads subcategories**. Road Bikes is shown at 14,519,438.00 and Mountain Bikes at 9,952,254.00. No image regeneration or figure alteration was needed. Minor spaces around hyphens in displayed product labels are presentation differences; the notes preserve the supplied SQL-result labels and keys.

The top-customer card names Kaitlyn Henderson, but Nichole Nara ties at the same total. The Fewest Orders card names Chloe Young as one selected example, not as the only customer with one order. Do not infer unique winners from those cards. Source currency remains unverified.

## 14. Key Takeaways

- Ranking identifies top and bottom performers within a defined population.
- `GROUP BY` aggregates business measures at the chosen grain.
- `ORDER BY` determines the ranking direction and can provide deterministic tie-breaking.
- `TOP` limits results; it needs appropriate ordering to identify leaders or laggards.
- `ROW_NUMBER`, `RANK`, and `DENSE_RANK` handle positions and ties differently.
- Tie-handling changes which rows appear and sometimes how many rows are returned.
- Sales rankings must be interpreted in the context of joins, current dimensions, missing references, time scope, and unverified currency.
- Ranking Analysis provides a foundation for future interactive dashboards and advanced analytics; it does not itself implement those systems.

## 15. Foundational EDA Completion

All six substantive lesson scripts exist locally and have been statically inspected as read-only. Local foundational coverage and publication status are distinct:

| Stage | Local coverage | Publication/documentation status for this milestone |
|---|---|---|
| 01 — Database Exploration | Metadata queries | Previously published SQL and fundamentals notes |
| 02 — Dimension Exploration | Distinct countries, categories, and hierarchy | Previously published SQL and notes |
| 03 — Date Exploration | Date boundaries, approximate age boundaries, and missing-date counts | Local SQL only; uncommitted and outside this commit scope; no dedicated notes published |
| 04 — Measure Exploration | Overall business KPIs | Previously published SQL, notes, and static KPI board |
| 05 — Magnitude Analysis | Dimension-based aggregates | Previously published SQL, notes, and static board; two supplied result captures remain partial |
| 06 — Ranking Analysis | Top/bottom products, subcategories, customers, and window ranks | SQL, notes, and static ranking board included in this milestone |

Together, the stages progress from understanding database objects to describing dimensions and dates, measuring overall activity, comparing grouped measures, and focusing on top/bottom performers. This is foundational educational EDA coverage, not a deployed production analytics platform or a claim that every local lesson is published.

Lesson 03 relies on the client's selected database context, and its `DATEDIFF(YEAR)` age values count year boundaries rather than exact birthdays, as its comments explain. Lesson 05 retains its leading country query before `USE DataWarehouse`; select the correct database before running the full file. These context caveats do not require changing the preserved SQL in this task.

Before the interactive dashboard phase, publish/review the separate Lesson 03 work under its own scope, capture the missing Bikes average cost and complete country-quantity breakdown from Lesson 05, define snapshot/date/currency semantics, and validate current join cardinalities. All interactive and advanced-analytics work remains planned.

See the [analytics roadmap](README.md), [Magnitude Analysis notes](NOTES_MAGNITUDE_ANALYSIS.md), and [Measure Exploration notes](NOTES_MEASURE_EXPLORATION.md).
