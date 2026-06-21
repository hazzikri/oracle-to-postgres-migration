-- =============================================================================
-- Oracle to PostgreSQL Migration Toolkit
-- File: 03_post_migration_validation.sql
-- Purpose: Run these queries AFTER migration to verify data integrity (100%)
-- =============================================================================

-- =============================================================================
-- SECTION 1: Row Count Verification
-- Run these on BOTH Oracle (source) and PostgreSQL (target) — counts must match
-- =============================================================================

-- Total employee count
SELECT COUNT(*) AS total_employees FROM employees;

-- Count by status
SELECT status, COUNT(*) AS cnt
FROM employees
GROUP BY status
ORDER BY status;

-- Count by department
SELECT dept_id, COUNT(*) AS cnt
FROM employees
GROUP BY dept_id
ORDER BY dept_id;


-- =============================================================================
-- SECTION 2: NULL / Data Integrity Checks
-- =============================================================================

-- Find any employees with NULL primary keys (should return 0 rows)
SELECT emp_id FROM employees WHERE emp_id IS NULL;

-- Find employees with invalid status values
SELECT emp_id, status FROM employees
WHERE status NOT IN ('A', 'I', 'T');

-- Find orphaned employees (dept_id references non-existent department)
SELECT e.emp_id, e.dept_id
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE e.dept_id IS NOT NULL AND d.dept_id IS NULL;

-- Find departments with no employees
SELECT d.dept_id, d.dept_name
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
WHERE e.emp_id IS NULL;


-- =============================================================================
-- SECTION 3: Numeric Precision Checks
-- =============================================================================

-- Verify salary precision is maintained (no rounding artifacts)
SELECT emp_id, salary
FROM employees
WHERE salary != ROUND(salary, 2)
LIMIT 20;

-- Salary range sanity check
SELECT
    MIN(salary)  AS min_salary,
    MAX(salary)  AS max_salary,
    AVG(salary)  AS avg_salary,
    STDDEV(salary) AS stddev_salary
FROM employees
WHERE salary IS NOT NULL;


-- =============================================================================
-- SECTION 4: Date/Timestamp Integrity
-- =============================================================================

-- Ensure hire_date is not in the future
SELECT emp_id, hire_date
FROM employees
WHERE hire_date > NOW();

-- Ensure created_at is properly populated
SELECT COUNT(*) AS missing_created_at
FROM employees
WHERE created_at IS NULL;

-- Check for suspiciously old dates (possible Oracle DATE format misparse)
SELECT emp_id, hire_date
FROM employees
WHERE hire_date < '1970-01-01'
LIMIT 10;


-- =============================================================================
-- SECTION 5: Index and Performance Validation
-- =============================================================================

-- List all indexes on the employees table
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'employees'
ORDER BY indexname;

-- Test query performance with EXPLAIN ANALYZE
EXPLAIN ANALYZE
SELECT *
FROM employees
WHERE dept_id = 1 AND status = 'A'
ORDER BY salary DESC
LIMIT 100;


-- =============================================================================
-- SECTION 6: Sequence Continuity Check
-- =============================================================================

-- Find gaps in emp_id sequence (potential missing rows during migration)
SELECT curr_id + 1 AS gap_start
FROM (
    SELECT emp_id AS curr_id,
           LEAD(emp_id) OVER (ORDER BY emp_id) AS next_id
    FROM employees
) seq_check
WHERE next_id - curr_id > 1
LIMIT 20;

-- Verify sequence current value is higher than max ID
SELECT
    last_value AS seq_current_value,
    (SELECT MAX(emp_id) FROM employees) AS max_emp_id,
    CASE
        WHEN last_value >= (SELECT MAX(emp_id) FROM employees)
        THEN 'PASS — Sequence is safe'
        ELSE 'FAIL — Sequence may cause PK conflict!'
    END AS validation_result
FROM seq_emp_id;
