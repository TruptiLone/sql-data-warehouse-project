# RetailFlow 360 — SQL Analytics

This section develops SQL exploration and business analysis on the local `DataWarehouse` database. Database exploration inspects metadata; dimension exploration reads the existing Gold views. The SQL lesson files are preserved as authored, and the accompanying notes explain their concepts and known warehouse findings.

## Available lessons and notes

| Resource | Purpose |
|---|---|
| [Database Fundamentals](NOTES_DATABASE_FOUNDATIONS.md) | Understand the local environment, warehouse layers, tables, views, keys, and metadata |
| [01 — Database Exploration SQL](01_database_exploration.sql) | Explore database objects and Gold customer-column metadata |
| [02 — Dimension Exploration SQL](02_dimension_exploration.sql) | Explore distinct countries, categories, and product hierarchy |
| [Dimension Exploration Notes](NOTES_DIMENSION_EXPLORATION.md) | Explain DISTINCT, cardinality, granularity, grouped counts, and missing category mappings |

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
| Date Exploration | Upcoming | Investigate date ranges with `MIN`, `MAX`, and date functions |
| Further EDA | Upcoming | Explore measures and grouped results with explicit data grain |
| Advanced analytics | Upcoming | Develop deeper business questions and appropriate analytical queries |

## Upcoming work

Date Exploration with `MIN`, `MAX`, and date functions is the next planned lesson. Further exploratory data analysis (EDA) and advanced analytics lessons may extend into sales measures, aggregations, and business questions. These are planned topics, not completed deliverables; links will be added when the actual files exist.

See the [local warehouse overview](../README.md) for the broader CRM/ERP warehouse context.
