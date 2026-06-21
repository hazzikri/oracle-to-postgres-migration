-- =============================================================================
-- Oracle to PostgreSQL Migration Toolkit
-- File: 02_stored_procedure_migration.sql
-- Purpose: Translate Oracle PL/SQL stored procedures to PostgreSQL PL/pgSQL
-- =============================================================================

-- =============================================================================
-- EXAMPLE 1: Basic Oracle stored procedure → PostgreSQL function
-- =============================================================================

-- ORACLE PL/SQL (source):
-- CREATE OR REPLACE PROCEDURE UPDATE_EMPLOYEE_STATUS(
--     p_emp_id  IN NUMBER,
--     p_status  IN VARCHAR2
-- )
-- AS
--     v_count NUMBER;
-- BEGIN
--     SELECT COUNT(*) INTO v_count FROM EMPLOYEES WHERE EMP_ID = p_emp_id;
--     IF v_count = 0 THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Employee not found: ' || p_emp_id);
--     END IF;
--     UPDATE EMPLOYEES SET STATUS = p_status, UPDATED_AT = SYSDATE
--     WHERE EMP_ID = p_emp_id;
--     COMMIT;
-- END;

-- PostgreSQL PL/pgSQL (migrated):
CREATE OR REPLACE FUNCTION update_employee_status(
    p_emp_id  BIGINT,
    p_status  CHAR(1)
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    -- NVL equivalent: COALESCE; COUNT(*) works the same
    SELECT COUNT(*) INTO v_count FROM employees WHERE emp_id = p_emp_id;

    IF v_count = 0 THEN
        -- RAISE_APPLICATION_ERROR → RAISE EXCEPTION in PG
        RAISE EXCEPTION 'Employee not found: %', p_emp_id
            USING ERRCODE = 'P0001';
    END IF;

    UPDATE employees
    SET status = p_status,
        created_at = NOW()   -- SYSDATE → NOW()
    WHERE emp_id = p_emp_id;

    -- Note: PostgreSQL uses autocommit by default. COMMIT inside function
    -- is not supported (use transaction management at the caller level).
END;
$$;


-- =============================================================================
-- EXAMPLE 2: Oracle CURSOR with LOOP → PostgreSQL FOR LOOP
-- =============================================================================

-- ORACLE (source):
-- PROCEDURE DEACTIVATE_DEPT(p_dept_id IN NUMBER) AS
--     CURSOR c_emp IS
--         SELECT EMP_ID FROM EMPLOYEES WHERE DEPT_ID = p_dept_id;
-- BEGIN
--     FOR rec IN c_emp LOOP
--         UPDATE EMPLOYEES SET STATUS = 'I' WHERE EMP_ID = rec.EMP_ID;
--     END LOOP;
--     COMMIT;
-- END;

-- PostgreSQL (migrated):
CREATE OR REPLACE FUNCTION deactivate_department(p_dept_id INTEGER)
RETURNS INTEGER   -- Returns count of employees deactivated
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER := 0;
    rec     RECORD;
BEGIN
    -- PostgreSQL FOR loop over query — equivalent to Oracle cursor FOR loop
    FOR rec IN
        SELECT emp_id FROM employees WHERE dept_id = p_dept_id AND status = 'A'
    LOOP
        UPDATE employees SET status = 'I' WHERE emp_id = rec.emp_id;
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;


-- =============================================================================
-- EXAMPLE 3: Oracle DECODE → PostgreSQL CASE WHEN
-- =============================================================================

-- Oracle query using DECODE:
-- SELECT EMP_ID, DECODE(STATUS, 'A', 'Active', 'I', 'Inactive', 'T', 'Terminated', 'Unknown')
-- FROM EMPLOYEES;

-- PostgreSQL equivalent:
SELECT
    emp_id,
    CASE status
        WHEN 'A' THEN 'Active'
        WHEN 'I' THEN 'Inactive'
        WHEN 'T' THEN 'Terminated'
        ELSE 'Unknown'
    END AS status_label
FROM employees;


-- =============================================================================
-- EXAMPLE 4: Oracle NVL, NVL2 → PostgreSQL COALESCE, CASE
-- =============================================================================
-- NVL(expr, default_val)  → COALESCE(expr, default_val)
-- NVL2(expr, val_if_not_null, val_if_null) → CASE WHEN expr IS NOT NULL THEN ... ELSE ... END

SELECT
    emp_id,
    COALESCE(full_name, 'Unknown Employee')                       AS display_name,
    CASE WHEN notes IS NOT NULL THEN 'Has Notes' ELSE 'No Notes' END AS notes_status
FROM employees;


-- =============================================================================
-- EXAMPLE 5: Oracle ROWNUM pagination → PostgreSQL LIMIT/OFFSET
-- =============================================================================

-- Oracle (top 10 highest paid):
-- SELECT * FROM (
--     SELECT ROWNUM AS rn, e.* FROM EMPLOYEES e ORDER BY SALARY DESC
-- ) WHERE rn <= 10;

-- PostgreSQL (clean):
SELECT *
FROM employees
ORDER BY salary DESC
LIMIT 10
OFFSET 0;  -- page 2 would be OFFSET 10

-- Or using ROW_NUMBER() window function (closer to Oracle behavior):
SELECT *
FROM (
    SELECT *, ROW_NUMBER() OVER (ORDER BY salary DESC) AS rn
    FROM employees
) ranked
WHERE rn BETWEEN 1 AND 10;
