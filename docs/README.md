# Documentation and diagrams

This folder contains architecture references, data-model visuals, and early project notes. The **implemented local SQL Server warehouse** is documented separately in [`local-sqlserver/docs/`](../local-sqlserver/docs/).

## Diagrams (course-provided reference visuals)

| File | What it shows |
|---|---|
| [Data architecture](reference/data_architecture.png) | High-level source systems and warehouse layers |
| [Data flow / lineage](reference/data_flow.png) | Movement of data through Bronze, Silver, and Gold |
| [Data integration](reference/data_integration.png) | CRM and ERP data relationships |
| [Data model](reference/data_model.png) | Customer and product dimensions with the sales fact |

These uploaded diagrams are retained as **reference visuals**. For the exact implemented schemas, procedures, business rules, and current deployment state, use the local-server documentation linked below.

## Other resources

- [Data layers (PDF)](data_layers.pdf) — conceptual Bronze/Silver/Gold reference; source and redistribution terms are pending review.
- [Azure SQL Database setup](azure-setup.md) — the original cloud setup notes (schemas and Bronze load only).
- [Analyze the source system](01_analyze_the_source_system.md) — early project planning notes, including historical Azure-oriented decisions. Do not treat this document as the current local deployment description.

## Verified local implementation

- [RetailFlow 360 local project overview](../local-sqlserver/README.md)
- [Implementation and data-quality guide](../local-sqlserver/docs/IMPLEMENTATION_GUIDE.md)
- [Local setup](../local-sqlserver/docs/LOCAL_SETUP.md)
- [Gold logical model](../local-sqlserver/docs/gold/LOGICAL_MODEL.md)
- [Gold data dictionary](../local-sqlserver/docs/gold/DATA_DICTIONARY.md)
- [Readiness review](../local-sqlserver/docs/READINESS_REVIEW.md)

The current local Gold layer uses three **SQL views**, and Silver uses the verified `silver.refresh_all` process. Course-derived reference material should not be confused with independently developed diagrams or a description of the exact deployed implementation.
