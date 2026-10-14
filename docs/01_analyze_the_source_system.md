# Step 1: Analyze the Source System

## 1. Objective

Before designing and implementing a data warehouse, we must analyze the source systems to understand their business context, data ownership, technical architecture, integration capabilities, and extraction requirements.

This step is called **Analyze the Source System**.

In real-world data engineering projects, this analysis involves collaborating with business stakeholders, data owners, database administrators, and technical teams to gather requirements and understand how data is created, stored, and consumed.

**Goal:** Establish a clear understanding of the source systems before building ETL pipelines and designing the data warehouse.

---

## 2. Business Context & Ownership

The first step is to understand the business purpose of the data and identify the stakeholders responsible for it.

### Key Questions

- **Data Ownership:** Who owns and maintains the source data?
- **Business Processes:** Which business operations depend on this data?
- **Documentation:** Is there existing technical or business documentation?
- **Data Model:** Are source schemas, relationships, and data catalogs available?

### Application to This Project

Our project uses two logical source systems:

**CRM — Customer Relationship Management**

Contains:
- Customer information
- Product information
- Sales transactions

**ERP — Enterprise Resource Planning**

Contains:
- Customer demographic information
- Customer location information
- Product categories and subcategories

The data will support business analytics such as sales performance, customer behavior, product performance, and geographic revenue analysis.

**Note:** CRM and ERP are represented by course-provided CSV extracts. Actual organizational ownership and stakeholder requirements have not been independently verified.

---

## 3. Architecture & Technology Stack

Understanding the technical environment helps determine how data should be extracted and integrated into the data warehouse.

### Key Questions

**How is the data stored?**
- Relational databases such as SQL Server, Oracle, or PostgreSQL
- Cloud platforms such as AWS or Azure
- File-based systems such as CSV, JSON, or Parquet

**What integration capabilities are available?**
- REST APIs
- Direct database connections
- Message queues such as Kafka
- File exports
- Change Data Capture (CDC)

### Application to This Project

| Component | Technology |
|---|---|
| Source systems | CRM and ERP (represented by CSV exports) |
| Data format | CSV |
| Data warehouse | Azure SQL Database |
| Query language | T-SQL |
| Development environment | Visual Studio Code |
| Architecture | Medallion Architecture (Bronze, Silver, Gold) |

**Initial integration strategy:** Ingest CSV extracts into the Bronze layer of the Azure SQL data warehouse.

Direct access to the original CRM and ERP databases is not available.

---

## 4. Extract & Load Requirements

Before building ingestion pipelines, determine how much data must be extracted, how frequently it changes, and what technical constraints apply.

### 4.1 Full Load vs. Incremental Load

**Full Load**

Loads the entire source dataset during each execution.

- Simple to implement and maintain.
- Suitable for smaller datasets.
- Reprocesses previously loaded records.

**Incremental Load**

Loads only newly created or modified records.

- Reduces unnecessary processing.
- More suitable for large, frequently changing datasets.
- Requires reliable change tracking and additional processing logic.

**Project Decision:** Phase 1 will use full-refresh batch loading, following the course implementation.

### 4.2 Data Scope & Historical Requirements

Identify:
- Which datasets and columns are required.
- Whether historical records must be preserved.
- How updates and deleted records should be handled.
- Whether business reporting requires historical or current attribute values.

**Project Decision:** Load the available CRM and ERP historical extracts. Historical product records require special attention during transformation and dimensional modeling.

### 4.3 Expected Data Volume

The project uses six datasets:

| Source | Dataset | Purpose |
|---|---|---|
| CRM | `cust_info.csv` | Customer information |
| CRM | `prd_info.csv` | Product information |
| CRM | `sales_details.csv` | Sales transactions |
| ERP | `CUST_AZ12.csv` | Customer demographics |
| ERP | `LOC_A101.csv` | Customer locations |
| ERP | `PX_CAT_G1V2.csv` | Product categories |

The source extracts contain approximately **116,000 records in total**.

### 4.4 Data Volume Limitations

Investigate:
- Maximum extract size.
- Database storage limitations.
- Network bandwidth.
- Processing time and compute requirements.
- Batch-size limitations.

For this project, the initial data volume is manageable using Azure SQL Database.

### 4.5 Source System Performance

Data extraction should avoid negatively impacting operational systems.

Recommended approaches:
- Schedule heavy extraction workloads during off-peak hours.
- Use batching for large datasets.
- Consider read replicas or exported snapshots.
- Use incremental extraction when appropriate.
- Monitor extraction performance.

Because our project uses existing CSV exports, the initial ingestion does not query the live operational CRM or ERP systems.

### 4.6 Authentication & Authorization

Understand how source systems are secured.

Common mechanisms include:
- Authentication tokens
- SSH keys
- VPN connections
- IP allowlisting
- Role-based access control

**Project Implementation:**
- Azure SQL Database access is configured through Microsoft Entra authentication.
- Network access is restricted using Azure SQL firewall rules.
- Database connections use encryption.
- Credentials and sensitive infrastructure information are excluded from the public GitHub repository.

---

## 5. Initial Data Quality Considerations

Source system analysis should identify potential data-quality issues before transformation.

| Potential issue | Proposed handling |
|---|---|
| Duplicate customer records | Deduplication using business-defined rules |
| Missing customer attributes | Null handling and standardization |
| Inconsistent customer identifiers | Identifier normalization |
| Inconsistent gender or country values | Standardized value mapping |
| Missing or incorrect sales amounts | Business rule validation |
| Invalid dates | Date validation and exception handling |
| Historical product records | Version-aware transformations |

These observations will guide the Silver-layer transformation logic and data-quality checks.

---

## 6. Questions for Stakeholders

Before implementing a production data pipeline, confirm:

1. Which source system is authoritative for customer information?
2. What is the expected data refresh frequency?
3. Do we need a full historical load or only recent records?
4. What defines a valid sales transaction?
5. How should conflicting values across source systems be resolved?
6. How should invalid or duplicate records be handled?
7. What data retention and security requirements apply?
8. What are the acceptable processing times and performance limits?

For this educational project, unresolved business requirements will be documented as assumptions rather than presented as confirmed stakeholder decisions.

---

## 7. Decisions for Phase 1

| Area | Decision |
|---|---|
| Source systems | CRM and ERP |
| Input format | CSV |
| Database platform | Azure SQL Database |
| Data loading approach | Full-refresh batch loading |
| Data architecture | Bronze, Silver, Gold |
| Transformation language | T-SQL |
| Data modeling approach | Dimensional modeling |
| Data validation | SQL data-quality checks |

---

## 8. Expected Outcome

After completing source system analysis, we should have:

- A clear understanding of the source systems and business context.
- An inventory of datasets and their purposes.
- Initial data volume and historical requirements.
- A defined extraction and loading strategy.
- Identified data quality challenges.
- Documented security and integration requirements.
- A list of assumptions and unresolved stakeholder questions.

**Next Step:** Design and implement the data warehouse architecture, starting with the Bronze layer for raw source data ingestion.

---

## Key Learning

**Analyze the Source System** is a critical requirement-gathering activity in data engineering.

It ensures that ETL pipelines and data models are designed based on the meaning, structure, ownership, and limitations of the source data—not merely on assumptions about individual columns.

Understanding the source systems before implementation helps improve data quality, reduce integration issues, and produce trustworthy analytical results.
