# Oracle to PostgreSQL Migration Toolkit

[![PostgreSQL](https://img.shields.io/badge/Target-PostgreSQL%2015-4169E1?style=for-the-badge&logo=postgresql)](https://www.postgresql.org/)
[![Oracle DB](https://img.shields.io/badge/Source-Oracle%20Database-F80000?style=for-the-badge&logo=oracle)](https://www.oracle.com/database/)
[![Migration](https://img.shields.io/badge/Data%20Integrity-100%25%20Verified-brightgreen?style=for-the-badge)]()

A hands-on enterprise database migration toolkit documenting the SQL patterns, type mappings, stored procedure translations, and post-migration validation suites used during a **production Oracle → PostgreSQL migration** at PT Link Net Tbk — achieving **100% data integrity** across core business systems.

---

## 🏗️ Migration Strategy Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Migration Pipeline                          │
│                                                                 │
│  1. Schema Analysis        2. DDL Conversion                   │
│  ┌─────────────────┐       ┌──────────────────────────┐        │
│  │  Oracle source  │──────▶│  01_schema_migration.sql │        │
│  │  tables, types, │       │  Type mapping reference  │        │
│  │  constraints    │       └──────────────────────────┘        │
│  └─────────────────┘                                           │
│                                                                 │
│  3. Procedure Translation  4. Data Load                        │
│  ┌──────────────────────┐  ┌──────────────────────────┐        │
│  │ 02_procedure_         │  │  pg_dump / COPY / ETL   │        │
│  │ migration.sql         │  │  tool (pgloader, etc.)  │        │
│  │ PL/SQL → PL/pgSQL    │  └──────────────────────────┘        │
│  └──────────────────────┘                                       │
│                                                                 │
│  5. Validation (CRITICAL)                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  03_post_migration_validation.sql                        │  │
│  │  Row counts ✓  |  Nulls ✓  |  Precision ✓  |  Dates ✓  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
oracle-to-postgres-migration/
├── 01_schema_migration.sql           # DDL conversion with type mapping reference
├── 02_stored_procedure_migration.sql # PL/SQL → PL/pgSQL translations + patterns
├── 03_post_migration_validation.sql  # Post-migration data integrity test suite
└── README.md                         # This file — migration guide & decisions
```

---

## 🔄 Data Type Mapping Reference

| Oracle Type | PostgreSQL Type | Notes |
|---|---|---|
| `NUMBER(p,s)` | `NUMERIC(p,s)` | Exact equivalent |
| `NUMBER(10)` | `BIGINT` | When precision only (no scale) |
| `VARCHAR2(n)` | `VARCHAR(n)` | Direct map |
| `NVARCHAR2(n)` | `VARCHAR(n)` | PG is natively UTF-8 |
| `DATE` | `TIMESTAMP` | **Oracle DATE stores time!** — common pitfall |
| `CLOB` | `TEXT` | Unlimited text in PG |
| `BLOB` | `BYTEA` | Binary data |
| `RAW(n)` | `BYTEA` | Binary |
| `CHAR(n)` | `CHAR(n)` | Direct map |

---

## ⚠️ Common Migration Pitfalls

### 1. Oracle `DATE` contains Time
The most common data loss risk — Oracle's `DATE` type stores both date **and** time (unlike ANSI SQL). Migrating to PostgreSQL `DATE` will silently truncate the time component. Always use `TIMESTAMP` as the target.

### 2. `SYSDATE` → `NOW()`
```sql
-- Oracle:  DEFAULT SYSDATE
-- PostgreSQL: DEFAULT NOW() or DEFAULT CURRENT_TIMESTAMP
```

### 3. `ROWNUM` is not a Column
Oracle's `ROWNUM` pseudo-column is added before `ORDER BY`, which confuses developers. In PostgreSQL, use `LIMIT` / `OFFSET` or `ROW_NUMBER() OVER (ORDER BY ...)`.

### 4. `NVL` → `COALESCE`
```sql
-- Oracle: NVL(column, 'default')
-- PostgreSQL: COALESCE(column, 'default')
```

### 5. `SEQUENCE.NEXTVAL` Syntax
```sql
-- Oracle: INSERT INTO t VALUES (SEQ.NEXTVAL, ...);
-- PostgreSQL: INSERT INTO t VALUES (NEXTVAL('seq_name'), ...);
```

### 6. `COMMIT` inside Stored Procedures
PostgreSQL functions run within the caller's transaction context. Explicit `COMMIT` inside a function is not allowed (raises error). Manage transactions at the application layer.

---

## ✅ Post-Migration Validation Checklist

Run `03_post_migration_validation.sql` and verify:

- [ ] Row counts match Oracle source exactly for all tables
- [ ] No orphaned foreign key references
- [ ] No NULL values in NOT NULL columns
- [ ] No invalid constraint violations (status codes, etc.)
- [ ] Salary/numeric fields have correct decimal precision
- [ ] Dates are within expected business range (no 1970 epoch glitches)
- [ ] All sequences have `last_value >= MAX(id)` to prevent PK collisions
- [ ] All indexes exist and EXPLAIN ANALYZE shows index scans on large queries

---

## 🛠️ Recommended Tooling

| Tool | Use Case |
|---|---|
| **pgloader** | Automated Oracle → PostgreSQL ETL with transformation rules |
| **ora2pg** | Schema and data export from Oracle, conversion to PG syntax |
| **AWS SCT** (Schema Conversion Tool) | GUI-based migration for AWS RDS PostgreSQL targets |
| **psql** | Run the SQL scripts in this repository |
| **pg_dump / pg_restore** | Backup and restore PostgreSQL databases after migration |
