-- =============================================================================
-- Oracle to PostgreSQL Migration Toolkit
-- File: 01_schema_migration.sql
-- Purpose: PostgreSQL DDL equivalent of Oracle schema with type mapping notes
-- =============================================================================

-- ─── DATA TYPE MAPPING REFERENCE ─────────────────────────────────────────────
-- Oracle              → PostgreSQL
-- NUMBER(p,s)         → NUMERIC(p,s) or DECIMAL(p,s)
-- NUMBER(p)           → NUMERIC(p,0) or INTEGER/BIGINT based on range
-- VARCHAR2(n)         → VARCHAR(n) or TEXT
-- NVARCHAR2(n)        → VARCHAR(n)  (PostgreSQL is UTF-8 natively)
-- DATE                → TIMESTAMP   (Oracle DATE includes time!)
-- TIMESTAMP           → TIMESTAMP
-- CLOB                → TEXT
-- BLOB                → BYTEA
-- CHAR(n)             → CHAR(n)
-- RAW(n)              → BYTEA
-- ROWNUM              → No equivalent — use LIMIT/OFFSET or ROW_NUMBER()
-- SYSDATE             → NOW() or CURRENT_TIMESTAMP
-- NVL(a,b)            → COALESCE(a,b)
-- DECODE(...)         → CASE WHEN ... THEN ... END
-- SEQUENCE.NEXTVAL    → NEXTVAL('sequence_name')
-- Dual table          → Remove — PostgreSQL doesn't need it
-- ─────────────────────────────────────────────────────────────────────────────

-- =============================================================================
-- EXAMPLE ENTERPRISE TABLE MIGRATION
-- Oracle source: EMPLOYEES table from a telecom BSS/OSS system
-- =============================================================================

-- Oracle DDL (for reference):
-- CREATE TABLE EMPLOYEES (
--     EMP_ID       NUMBER(10)        NOT NULL,
--     EMP_CODE     VARCHAR2(20)      NOT NULL,
--     FULL_NAME    NVARCHAR2(100),
--     DEPT_ID      NUMBER(5),
--     HIRE_DATE    DATE,             -- Oracle DATE includes time!
--     SALARY       NUMBER(12,2),
--     STATUS       CHAR(1)           DEFAULT 'A',
--     CREATED_AT   TIMESTAMP         DEFAULT SYSDATE,
--     NOTES        CLOB,
--     CONSTRAINT PK_EMP PRIMARY KEY (EMP_ID),
--     CONSTRAINT CHK_STATUS CHECK (STATUS IN ('A', 'I', 'T'))
-- );

-- PostgreSQL DDL (migrated):
CREATE TABLE IF NOT EXISTS employees (
    emp_id        BIGINT              NOT NULL,           -- NUMBER(10) → BIGINT
    emp_code      VARCHAR(20)         NOT NULL,           -- VARCHAR2 → VARCHAR
    full_name     VARCHAR(100),                           -- NVARCHAR2 — native UTF-8
    dept_id       INTEGER,                                -- NUMBER(5) → INTEGER
    hire_date     TIMESTAMP WITHOUT TIME ZONE,            -- Oracle DATE includes time
    salary        NUMERIC(12, 2),                         -- NUMBER(12,2) → NUMERIC
    status        CHAR(1)             DEFAULT 'A',
    created_at    TIMESTAMP WITHOUT TIME ZONE
                  DEFAULT NOW(),                          -- SYSDATE → NOW()
    notes         TEXT,                                   -- CLOB → TEXT
    CONSTRAINT pk_employees        PRIMARY KEY (emp_id),
    CONSTRAINT chk_emp_status      CHECK (status IN ('A', 'I', 'T'))
);

-- Sequence migration (Oracle SEQUENCE → PostgreSQL SEQUENCE)
-- Oracle: CREATE SEQUENCE SEQ_EMP_ID START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS seq_emp_id
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER TABLE employees
    ALTER COLUMN emp_id SET DEFAULT NEXTVAL('seq_emp_id');

-- Index migration
-- Oracle: CREATE INDEX IDX_EMP_DEPT ON EMPLOYEES(DEPT_ID);
CREATE INDEX IF NOT EXISTS idx_employees_dept_id ON employees (dept_id);
CREATE INDEX IF NOT EXISTS idx_employees_status  ON employees (status);

-- =============================================================================
-- DEPARTMENTS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS departments (
    dept_id       INTEGER             NOT NULL,
    dept_code     VARCHAR(10)         NOT NULL UNIQUE,
    dept_name     VARCHAR(100)        NOT NULL,
    manager_id    BIGINT,
    CONSTRAINT pk_departments PRIMARY KEY (dept_id)
);

ALTER TABLE employees
    ADD CONSTRAINT fk_emp_dept
    FOREIGN KEY (dept_id) REFERENCES departments (dept_id)
    ON DELETE SET NULL;
