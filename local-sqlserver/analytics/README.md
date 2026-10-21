# RetailFlow 360 — SQL Analytics

This section develops SQL exploration and business analysis on the local `DataWarehouse` database. Database exploration inspects metadata; dimension exploration reads the existing Gold views. The SQL lesson files are preserved as authored, and the accompanying notes explain their concepts and known warehouse findings.

## RetailFlow 360 — Business KPI Dashboard

![RetailFlow 360 Analytics KPI Board](images/retailflow_360_kpi_board.png)

RetailFlow 360 uses SQL Server Gold-layer views to calculate core retail business metrics, including sales, quantity sold, order counts, product counts, and customer engagement. The KPI board presents a static summary of results from the Measure Exploration lesson.

The seven values are the project owner's recorded SQL results for the current snapshot, not newly executed results from this documentation task. **This is a static snapshot, not a live dashboard.** Decorative mini-charts are illustrative, not measured trends. Dollar symbols are unverified currency formatting; the Gold schema does not establish USD. Customer counts alone do not prove a conversion rate or engagement trend.

| KPI | Recorded SQL result |
|---|---:|
| Total Sales | 29,356,250.00 |
| Total Quantity | 60,423 |
| Average Unit Price | 486.04 |
| Total Orders | 27,659 |
| Total Current Products | 295 |
| Total Registered Customers | 18,484 |
| Total Purchasing Customers | 18,484 |

Average unit price is the unweighted arithmetic mean of recorded sales-line unit prices. Orders are distinct non-NULL order numbers, while purchasing customers are distinct non-NULL customer keys in the sales fact. Matching registered/purchasing counts do not alone establish full customer coverage.

Read the [Measure Exploration SQL](04_measure_exploration.sql) and [Measure Exploration Notes](NOTES_MEASURE_EXPLORATION.md) for definitions, grain, and interpretation.

## Magnitude Analysis — Business Insights

![RetailFlow 360 Magnitude Analysis Board](images/retailflow_360_magnitude_analysis_board.png)

This board summarizes captured customer, product, sales, and quantity breakdowns from the SQL Server Gold views. It is a **static graphical snapshot**, not a live dashboard or an exhaustive view of every group.

The average-product-cost capture omits Bikes, and the quantity-by-country capture omits France, Germany, and any unknown-country group. Those figures remain follow-ups; no missing values have been invented. Decorative graphics do not establish historical trends, and dollar symbols do not verify the source currency. The notes preserve query precision where the image rounds costs.

See [05 — Magnitude Analysis SQL](05_magnitude_analysis.sql) and [Magnitude Analysis Notes](NOTES_MAGNITUDE_ANALYSIS.md) for all supplied results, grouping/join explanations, reconciliation, and limitations. The preserved SQL has a duplicate country query before its `USE` statement; select `DataWarehouse` in the client before running the entire file.

## Available lessons and notes

| Resource | Purpose |
|---|---|
| [Database Fundamentals](NOTES_DATABASE_FOUNDATIONS.md) | Understand the local environment, warehouse layers, tables, views, keys, and metadata |
| [01 — Database Exploration SQL](01_database_exploration.sql) | Explore database objects and Gold customer-column metadata |
| [02 — Dimension Exploration SQL](02_dimension_exploration.sql) | Explore distinct countries, categories, and product hierarchy |
| [Dimension Exploration Notes](NOTES_DIMENSION_EXPLORATION.md) | Explain DISTINCT, cardinality, granularity, grouped counts, and missing category mappings |
| [04 — Measure Exploration SQL](04_measure_exploration.sql) | Calculate sales, quantity, price, order, product, and customer KPIs |
| [Measure Exploration Notes](NOTES_MEASURE_EXPLORATION.md) | Interpret aggregate functions, seven recorded KPIs, and the static dashboard |
| [05 — Magnitude Analysis SQL](05_magnitude_analysis.sql) | Compare customer, product, sales, and quantity measures across dimensions |
| [Magnitude Analysis Notes](NOTES_MAGNITUDE_ANALYSIS.md) | Explain GROUP BY, key-based joins, Top-N results, data quality, and partial captures |

## Reading the examples

The SQL examples use the `DataWarehouse` context and are read-only. `GO` requires a client that recognizes SQL Server batch separators, such as the MSSQL extension in VS Code. Historical snapshot findings are distinguished from illustrative records; writing these notes did not revalidate the live database.

The known `CO_PE`/`CO_PD` mismatch remains visible as missing category enrichment. The notes explain it without changing source mappings, Gold definitions, or ETL behavior.

## Learning roadmap

“Completed” below means the educational files are written and available; it does not imply a new live execution of every SQL example.

| Stage | Status | Learning outcome |
|---|---|---|
| Database fundamentals | Completed documentation | Explain the server, database, warehouse layers, tables, views, and relationships |
| 01 — Database Exploration | Completed SQL lesson | Inspect database objects and column metadata |
| 02 — Dimension Exploration | Completed SQL lesson and notes | Identify distinct values, understand hierarchy, and interpret missing mappings |
| 03 — Date Exploration | Local SQL draft present; not published in this milestone | Investigate date ranges with `MIN`, `MAX`, and date functions |
| 04 — Measure Exploration | Completed SQL lesson, notes, and static KPI snapshot | Calculate and interpret seven overall business metrics |
| 05 — Magnitude Analysis | Completed SQL lesson, notes, and static captured-results board; two captures remain partial | Combine dimensions and measures for country/category comparisons |
| 06 — Ranking Analysis | Upcoming | Identify top/bottom performers and define ranking/tie policies |
| Further EDA | Upcoming | Explore measures and grouped results with explicit data grain |
| Advanced analytics | Upcoming | Develop deeper business questions and appropriate analytical queries |

## Upcoming work

Lesson 06 — Ranking Analysis is next: extend grouped comparisons with top/bottom rankings and explicit tie handling. Before a complete dashboard comparison, capture the missing Bikes average cost and the full quantity-by-country result. Further EDA and advanced analytics remain upcoming. The local Lesson 03 SQL draft is outside this publishing milestone and is not linked as a published deliverable; existing lesson files are preserved. Links to future lessons will be added when they are ready and published.

See the [local warehouse overview](../README.md) for the broader CRM/ERP warehouse context.

### Future Work — Interactive Business Intelligence Dashboard

After completing Magnitude Analysis and Ranking Analysis, we plan to develop an interactive analytics dashboard. Potential capabilities include:

- KPI cards and sales-by-category comparisons.
- Customer geography and product performance views.
- Ranking and Top-N analysis.
- Filters by country, category, and time period.
- Data-quality indicators that retain unknown and missing mappings.
- SQL-backed data visualizations with clearly defined measures and grain.

These are **planned features**, not implemented functionality. The existing images are static learning artifacts; this milestone does not build a BI application, an AI agent, or an automated refresh pipeline.
