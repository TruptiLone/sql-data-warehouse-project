# SQL Data Analytics — Lesson 02: Dimension Exploration

**Objective:** Identify unique values within business dimensions to understand the countries, product categories, subcategories, and product hierarchy represented in our warehouse.

These notes accompany the existing [dimension exploration SQL](02_dimension_exploration.sql). Snapshot findings below reflect the supplied validated project findings and existing project documentation; they were not re-queried while writing these notes. Future data changes can change counts and distinct values. Illustrative examples are labeled separately.

## 1. What is Dimension Exploration?

Dimensions describe business entities and provide attributes used to organize or group business data. In RetailFlow 360, customer country describes customers; category, subcategory, and product name describe products. A dimension view can contain many descriptive attributes, not just one column.

Dimension exploration asks which values exist before calculating measures such as sales totals. This helps us understand the business coverage of the data and identify unexpected or missing labels.

SQL `DISTINCT` eliminates duplicate values from a `SELECT` result. Consider this **illustrative input**, not actual warehouse records:

| country |
|---|
| Germany |
| United States |
| Germany |
| France |
| United States |

Selecting `DISTINCT country` returns Germany, United States, and France once each: three rows instead of five. Without `ORDER BY`, the display order is not guaranteed; with `ORDER BY country`, the result is sorted according to the database collation.

**Cardinality** is the number of distinct values in an attribute. Category usually has low cardinality because many products share a small number of category labels. Product name usually has higher cardinality because it describes more specific offerings. A name is not necessarily a unique product identifier, however.

When reporting cardinality, state whether SQL `NULL` is included: `SELECT DISTINCT` and `COUNT(DISTINCT ...)` treat it differently, as explained in the knowledge check.

## 2. Explore Customer Countries

```sql
USE DataWarehouse;
GO

SELECT DISTINCT
    country
FROM gold.dim_customers
ORDER BY country;
```

The supplied validated snapshot contains:

- Australia
- Canada
- France
- Germany
- United Kingdom
- United States
- `n/a`

There are **six named countries plus an additional `'n/a'` category** representing unknown country information. The literal text `'n/a'` is a stored value and is not SQL `NULL`.

`DISTINCT` returns unique values, not their frequencies. This query identifies the geographic coverage represented in the customer dimension; it does not tell us which country has the most customers. That question needs an aggregation such as a customer-record count grouped by country.

## 3. Explore Product Categories

Run the following examples in the `DataWarehouse` context selected above.

```sql
SELECT DISTINCT
    category
FROM gold.dim_products
ORDER BY category;
```

Our four named product categories are:

- Accessories
- Bikes
- Clothing
- Components

The known integration issue is that **seven current products have unmatched CRM/ERP category codes: CRM uses `CO_PE`, while ERP has `CO_PD` for Pedals**. The exact-match enrichment cannot resolve these codes. Because the Gold product view preserves current CRM products through a left join, those records remain present with `NULL` category values.

Therefore, the documented snapshot includes **four named categories plus SQL `NULL`**. `NULL` is not a fifth named business category. Its presence signals missing enrichment, not a legitimate category called “NULL.” The codes have not been silently equated; resolving the mapping requires a justified business/source-data decision.

This is why dimension exploration is also a data-quality activity: an apparently simple list of labels can expose an integration gap.

## 4. Understand Product Hierarchy

**Category → Subcategory → Product Name**

For example, **Bikes → Mountain Bikes → Mountain-100** is an illustrative hierarchy. It explains the levels of detail and is not asserted to be an exact stored three-column combination in the current warehouse.

```sql
SELECT DISTINCT
    category,
    subcategory,
    product_name
FROM gold.dim_products
ORDER BY
    category,
    subcategory,
    product_name;
```

With multiple selected columns, `DISTINCT` returns unique **combinations**. Two rows are duplicates for this query only when their selected category, subcategory, and product-name values match under SQL comparison rules. It does not deduplicate each column separately and then combine unrelated values.

**Granularity** means the level of detail. Category-level information is broad: Bikes can cover many offerings. Subcategory adds detail, and product-level information is more specific. Cardinality counts distinct values; granularity describes what level those values represent.

The recorded Gold product view has **295 rows**, representing current products. The number of distinct category/subcategory/product-name combinations is not necessarily 295. Different product records can share the same descriptive combination, and this query does not select a unique product key. Its exact distinct-combination count has not been measured in these notes.

## 5. Count Products by Category

Unique labels answer “what exists?” Counts answer “how many records belong to each group?”

```sql
SELECT
    category,
    COUNT(*) AS product_count
FROM gold.dim_products
GROUP BY category
ORDER BY product_count DESC;
```

| SQL element | Role in this query |
|---|---|
| `category` | Dimension attribute used to classify products |
| `COUNT(*)` | Measure counting product records in each group, including records whose category is `NULL` |
| `AS product_count` | Names the result column so its meaning is clear |
| `GROUP BY category` | Organizes records into groups with the same category value, including one group for `NULL` |
| `ORDER BY product_count DESC` | Sorts groups from largest count to smallest; ties have no additional specified order |

The `NULL` group makes missing category enrichment visible. For the documented snapshot, the seven unmatched current products explain that unresolved group. Replacing `COUNT(*)` with `COUNT(category)` would exclude `NULL` values and return zero for the `NULL` group, hiding its record count.

This query counts product records, not units sold or sales revenue. Those measures require the sales fact view and appropriate joins. No per-category result counts were invented or newly measured here.

## 6. Knowledge Check

**Question:** If the customer dimension contains 18,484 records but seven distinct stored country values, what does `SELECT DISTINCT country` return?

**Answer: Seven rows.** Each row contains one distinct country value, including the stored text `'n/a'` in our documented snapshot. The query does not return all 18,484 customer rows.

Compare the result shapes:

```sql
-- A list: one result row for each distinct stored country value.
SELECT DISTINCT country
FROM gold.dim_customers
ORDER BY country;

-- A count: one result row containing the number of distinct non-NULL values.
SELECT COUNT(DISTINCT country) AS distinct_country_count
FROM gold.dim_customers;
```

For the stated snapshot of six named countries plus `'n/a'`, the second query returns one row with the value **7**. This is the expected result from the supplied snapshot, not a new execution result.

SQL `COUNT(DISTINCT country)` excludes SQL `NULL`, while `SELECT DISTINCT country` can include one `NULL` row. For example, if an illustrative dataset had those seven non-NULL labels and additional SQL `NULL` records, the list would contain eight rows, but the count would still be seven.

## 7. Key Takeaways

- Dimensions describe and categorize business entities.
- `DISTINCT` identifies unique stored values or unique combinations of selected columns.
- Cardinality describes the number of distinct values; make the `NULL` policy explicit.
- Hierarchies describe levels of granularity, from broad categories to detailed products.
- Combining dimensions with `COUNT`, `SUM`, and other measures helps generate business insights, provided the record grain and joins are correct.
- Dimension exploration can uncover missing or inconsistent source mappings, such as `CO_PE` versus `CO_PD`.

The **next planned lesson is Date Exploration**, using `MIN`, `MAX`, and date functions. It is upcoming work, not a completed lesson linked by these notes.

For the underlying server, schema, table, view, and relationship concepts, see [Database Fundamentals](NOTES_DATABASE_FOUNDATIONS.md). Return to the [analytics index](README.md) for the existing SQL lessons. The [local warehouse README](../README.md) records the Gold deployment context and known category-mapping issue.
