# Database Fundamentals — RetailFlow 360

These notes explain the database concepts behind RetailFlow 360 and connect them to our local CRM/ERP warehouse. Environment and deployment statements describe the recorded project state, not a new database inspection. No database commands were executed to write these notes.

## Contents

- [1. What is a Database Server?](#1-what-is-a-database-server)
- [2. What is a Database?](#2-what-is-a-database)
- [3. What is a Data Warehouse?](#3-what-is-a-data-warehouse)
- [4. What is a Database Schema?](#4-what-is-a-database-schema)
- [5. What is a Table?](#5-what-is-a-table)
- [6. What are Columns and Rows?](#6-what-are-columns-and-rows)
- [7. What is a View?](#7-what-is-a-view)
- [8. What is the Relationship Between Tables?](#8-what-is-the-relationship-between-tables)
- [9. How Everything Works Together](#9-how-everything-works-together)
- [10. How Data Flows Through RetailFlow 360](#10-how-data-flows-through-retailflow-360)
- [11. Database Exploration Using Metadata](#11-database-exploration-using-metadata)
- [12. Key Concepts to Remember](#12-key-concepts-to-remember)

## 1. What is a Database Server?

A database server runs database management software to store, retrieve, secure, and manage data. The database management system (DBMS) handles queries, access permissions, transactions, and concurrent requests. Microsoft SQL Server, PostgreSQL, MySQL, and Oracle are examples of DBMS products. The server software can run on a physical computer, a virtual machine, or in a container.

Our RetailFlow 360 environment is:

| Component | Our environment |
|---|---|
| DBMS | Microsoft SQL Server 2022 Developer |
| Hosting | Docker container on macOS |
| Local SQL endpoint | `127.0.0.1,14333` |
| SQL client | VS Code with the MSSQL extension |
| Database | `DataWarehouse` |

`127.0.0.1` refers to the local computer, and `14333` is the host port exposed for the SQL connection. SQL Server client connection strings commonly separate the host and port with a comma.

VS Code acts as a **client**. The MSSQL extension sends a query to SQL Server; SQL Server processes it and returns a result or error that VS Code displays. The editor is not the database engine, and a saved `.sql` file does not execute merely because it is opened.

## 2. What is a Database?

A database is an organized collection of related data managed by a DBMS. It also contains definitions of objects, permissions, and other metadata that describe and control that data.

One SQL Server instance can contain multiple databases. Our analytics database is named `DataWarehouse`. Selecting this database establishes the context in which names such as `gold.dim_customers` are resolved. The database name and the SQL Server instance are different concepts: the instance runs the software, while the database contains a particular collection of objects and data.

## 3. What is a Data Warehouse?

An operational database supports day-to-day activity, such as recording an order or updating a customer's address. An analytical data warehouse integrates data so people can compare, summarize, and investigate business activity across sources and time.

RetailFlow 360 integrates CRM and ERP sources for analytics and reporting. Its business-ready data helps answer questions such as:

- Which products generate the highest sales?
- Which countries have the most customers?
- How does revenue change over time?
- Which customer segments purchase particular products?

These questions typically require joins, aggregations, and clear definitions of measures. For example, counting customers by country describes the customer base; summing sales by country requires connecting sales to customers. A warehouse is defined by its analytical purpose and design, not simply by naming a database `DataWarehouse`.

## 4. What is a Database Schema?

A schema is a logical namespace that organizes objects such as tables, views, and stored procedures within a database. It also provides a boundary for organizing permissions. A schema is not a separate database or a filesystem folder.

| Schema | Purpose |
|---|---|
| `bronze` | Preserve source records for traceability |
| `silver` | Store cleaned and standardized data |
| `gold` | Present business-ready data for analytics |

`bronze.crm_cust_info` and `silver.crm_cust_info` are separate tables despite sharing the object name `crm_cust_info`. Their schema-qualified names are different. Bronze preserves the source representation, while Silver holds the cleaned customer representation.

In `DataWarehouse.gold.dim_customers`, the three parts identify the database, schema, and object. Once the database context is set, `gold.dim_customers` is sufficient.

## 5. What is a Table?

A table physically stores records in rows and columns. Its definition specifies column names, data types, and any constraints governing acceptable values.

`silver.crm_cust_info` is our cleaned CRM customer table. It supplies customer identifiers and attributes used when the Gold customer view integrates CRM information with ERP customer and location data. The Silver table stores rows; the Gold view defines how to read and combine them.

A table's rows have no guaranteed display order. An analytical query uses `ORDER BY` when a predictable result order matters.

## 6. What are Columns and Rows?

A **column**, or attribute, describes one kind of information, such as a customer identifier or name. A **row**, or record, holds the values for one record at the table's defined level of detail.

The following data is **illustrative only**, not actual warehouse records or the exact schema of `silver.crm_cust_info`:

| customer_id | first_name | country |
|---|---|---|
| 101 | Emma | United States |
| 102 | Noah | Germany |
| 103 | Olivia | France |

This example contains three columns and three rows. The header is not a data row.

SQL data types describe what a column can hold:

| Type | Meaning | Example use |
|---|---|---|
| `INT` | Whole number | A numeric identifier or quantity |
| `NVARCHAR(n)` | Variable-length Unicode text with a declared size limit | A name or country label |
| `DATE` | Calendar date without a time component | A birth date or order date |

An identifier can be numeric without being a quantity that should be summed. SQL `NULL` represents missing or unknown information; it is different from the text value `'n/a'`, an empty string, and zero.

## 7. What is a View?

A SQL view is defined by a saved `SELECT` query. A normal view does not independently store the query's result rows: querying the view reads through its definition to the underlying data. SQL Server also supports indexed views under specific rules, but that is not the Gold implementation here.

Our three deployed Gold views are:

| View | Purpose |
|---|---|
| `gold.dim_customers` | Integrated customer information |
| `gold.dim_products` | Current products and categories |
| `gold.fact_sales` | Sales records linked to customer and product dimensions |

**RetailFlow 360 Gold consists of SQL views, not physical Gold tables.** This gives analytics a consistent interface without copying these results into separate Gold tables. The product view filters for current products, so it does not expose every historical Silver product version.

## 8. What is the Relationship Between Tables?

A relationship connects records that refer to the same business entity or activity.

- A **primary key** uniquely identifies a row and cannot contain `NULL`. In a physical table, a declared primary-key constraint enforces this rule.
- A **foreign key** identifies a reference to a key in another table. A declared foreign-key constraint enforces valid references according to its definition.
- A **business key** is an identifier meaningful to the source business system, such as a customer number or product number.
- A **surrogate key** is a technical identifier used to relate records independently of the source business identifier.
- A **logical relationship** is a modeled connection that may be used and tested even when no physical foreign-key constraint enforces it.

A SQL `JOIN` combines records according to a condition. An `INNER JOIN` retains matching records; a `LEFT JOIN` retains records on the left even when the right side has no match, producing `NULL` for missing right-side attributes.

In RetailFlow 360, sales customer and product identifiers are matched with the dimensions. The Gold sales view exposes `customer_key` and `product_key`, allowing an analytics query to connect sales to descriptive customer and product attributes.

Our Gold views use logical relationships that the project records describe as validated. They are **not enforced through physical Gold foreign-key constraints**. Quality checks establish evidence about a tested snapshot; a join alone does not enforce referential integrity or guarantee that every source identifier matches.

The Gold dimension definitions generate surrogate keys with `ROW_NUMBER()`. These are calculated view values, not persisted identity keys; changes to the underlying ordered records can change the assignments. They should not be presented as permanent identifiers for external systems.

## 9. How Everything Works Together

**Computer → Docker Container → SQL Server → Database → Schemas → Tables/Views → Columns and Rows**

| Level | RetailFlow 360 meaning |
|---|---|
| Computer | The macOS host used for development |
| Docker container | The isolated runtime in which SQL Server runs through Docker's Linux environment |
| SQL Server | The DBMS that accepts connections and processes queries |
| Database | `DataWarehouse`, our collection of warehouse objects and data |
| Schemas | `bronze`, `silver`, and `gold`, which organize the layers |
| Tables/views | Stored source/cleaned tables and business-ready query definitions |
| Columns and rows | Attributes and records exposed by those objects |

VS Code sits outside this hierarchy as the client: it connects through the local endpoint and displays results. This hierarchy is a conceptual explanation, not a statement that a Docker container itself is the durable storage location.

## 10. How Data Flows Through RetailFlow 360

1. **CRM and ERP source CSV files:** the starting extracts contain customer, product, sales, and enrichment data.
2. **Bronze ingestion using Python and SQL Server:** source records enter Bronze tables so transformations can be traced back to their inputs.
3. **Silver transformation:** cleaning, deduplication, normalization, and data-quality checks create standardized data. Rules and unresolved exceptions remain documented rather than being silently guessed.
4. **Gold dimensional modeling:** three SQL views present customers, current products, and sales with logical dimension relationships.
5. **SQL Analytics:** exploration, joins, aggregations, and business questions use the Gold interface. The existing lessons currently cover database and dimension exploration; later analyses can build on them.

The project records describe a tested **`silver.refresh_all` transactional full-refresh procedure**. Its refresh operations and pre-commit quality gates run within a transaction. If a covered operation or gate fails before commit, rollback restores the prior transactional state instead of leaving a partially refreshed Silver layer. The recorded acceptance work includes two successful refreshes and two controlled rollback tests.

Those results belong to the previously tested revision. The newer local `silver.load_silver` revision is documented as awaiting acceptance; its presence in working files does not mean it has replaced the deployed procedure. A failure detected after a successful commit cannot retroactively roll back that commit.

This is a **full-refresh design**. Incremental loading and change data capture (CDC) are not implemented claims. These notes neither invoke a refresh nor change its implementation.

## 11. Database Exploration Using Metadata

Metadata is information about data structures: object names, column names, types, nullability, and similar definitions. Exploring it first helps avoid guessing the schema, selecting nonexistent columns, or confusing a table with a view.

`INFORMATION_SCHEMA.TABLES` lists accessible tables and views in the current database. Despite its name, it includes views; `TABLE_TYPE` distinguishes the object types. It is not a complete inventory of every object type, such as stored procedures.

```sql
USE DataWarehouse;
GO

SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

`INFORMATION_SCHEMA.COLUMNS` describes accessible columns. This example inspects the Gold customer view without reading its customer records:

```sql
USE DataWarehouse;
GO

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold'
  AND TABLE_NAME = 'dim_customers'
ORDER BY ORDINAL_POSITION;
```

Both examples are read-only. `USE` selects the database context, and `GO` is a batch separator understood by supporting SQL clients rather than a T-SQL statement that changes data. Metadata visibility depends on the connected user's permissions.

The existing [database exploration SQL](01_database_exploration.sql) also explores metadata. These notes explain the concepts without replacing or modifying that lesson file.

## 12. Key Concepts to Remember

| Concept | Reference |
|---|---|
| Database server | Runs the DBMS and handles storage, queries, security, and transactions |
| Database | Organized collection of related data and database objects |
| Data warehouse | Integrated data organized for analysis and reporting |
| Schema | Namespace for related database objects |
| Table | Stored records organized into columns and rows |
| Column | An attribute with a defined SQL data type |
| Row | One record at the object's defined level of detail |
| View | Saved query definition that normally reads underlying data without independently storing result rows |
| Primary and foreign keys | Unique row identifiers and references; physical constraints enforce them when declared |
| JOIN | Combines records using a relationship condition |
| ETL | Extract, transform, load: obtain source data, prepare it, and load a target; warehouse stages can distribute these operations across layers |
| SQL | Structured Query Language, used to define, query, and manage relational data; our examples here only query it |

**Takeaway:** RetailFlow 360 runs SQL Server locally in Docker. Within `DataWarehouse`, Bronze preserves sources, Silver standardizes them, and Gold views expose related business entities. VS Code sends SQL queries to that structure so descriptive attributes and sales measures can become useful analysis.

Related reading: [Dimension Exploration Notes](NOTES_DIMENSION_EXPLORATION.md) and the [analytics index](README.md). Environment and historical deployment context are recorded in the [local warehouse README](../README.md) and [implementation guide](../docs/IMPLEMENTATION_GUIDE.md).
