-- =============================================================================
-- 05_joins.sql
-- EMPLOYEE MANAGEMENT SYSTEM (EMS) - JOIN OPERATIONS
-- ORACLE 19c / PL-SQL
-- =============================================================================
-- OBJECTIVE:
--   - Demonstrate INNER, LEFT OUTER, RIGHT OUTER, and FULL OUTER JOINs
--   - Show multi-table joins connecting Employee, Department, and Payroll
--   - Compare join types and their results
--   - Handle NULL values in joined results
-- =============================================================================

SET SERVEROUTPUT ON;
SET PAGESIZE 100;
SET LINESIZE 150;

DBMS_OUTPUT.PUT_LINE('
╔═══════════════════════════════════════════════════════════════════════════╗
║                       EMS JOIN OPERATIONS & QUERIES                       ║
╚═══════════════════════════════════════════════════════════════════════════╝
');

-- =============================================================================
-- [SECTION 05.1] - INNER JOIN (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== INNER JOIN: ONLY MATCHING RECORDS ===

Returns rows where a match exists in BOTH tables.
Excludes unmatched records from either side.
');

DBMS_OUTPUT.PUT_LINE('Employee-Department Matches (INNER JOIN):');
DBMS_OUTPUT.PUT_LINE('─────────────────────────────────────────');

SELECT
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    e.gender,
    d.dept_name,
    d.salary_range
FROM EMPLOYEE e
INNER JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
ORDER BY d.dept_name, e.first_name;

-- =============================================================================
-- [SECTION 05.2] - LEFT OUTER JOIN (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== LEFT OUTER JOIN: KEEP ALL LEFT TABLE ROWS ===

Returns all rows from LEFT table + matching rows from RIGHT table.
Unmatched rows from RIGHT table show as NULL.
');

DBMS_OUTPUT.PUT_LINE('All Departments with Employee Counts (LEFT OUTER JOIN):');
DBMS_OUTPUT.PUT_LINE('───────────────────────────────────────────────────────');

SELECT
    d.job_id,
    d.dept_name,
    d.dept_description,
    COUNT(e.emp_id) as employee_count,
    COALESCE(e.first_name || ' ' || e.last_name, 'No employees') as example_employee
FROM JOB_DEPARTMENT d
LEFT OUTER JOIN EMPLOYEE e ON d.job_id = e.job_id
GROUP BY d.job_id, d.dept_name, d.dept_description, e.first_name, e.last_name
ORDER BY d.dept_name;

-- =============================================================================
-- [SECTION 05.3] - RIGHT OUTER JOIN (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== RIGHT OUTER JOIN: KEEP ALL RIGHT TABLE ROWS ===

Returns all rows from RIGHT table + matching rows from LEFT table.
Unmatched rows from LEFT table show as NULL.
');

DBMS_OUTPUT.PUT_LINE('All Salary Structures with Employee Assignments (RIGHT OUTER JOIN):');
DBMS_OUTPUT.PUT_LINE('────────────────────────────────────────────────────────────────────');

SELECT
    sb.salary_id,
    sb.amount,
    sb.bonus_amount,
    d.dept_name,
    COUNT(e.emp_id) as employees_with_this_salary,
    COALESCE(e.first_name || ' ' || e.last_name, 'No employees assigned') as example_employee
FROM SALARY_BONUS sb
RIGHT OUTER JOIN EMPLOYEE e ON sb.salary_id = e.salary_id
LEFT OUTER JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
GROUP BY sb.salary_id, sb.amount, sb.bonus_amount, d.dept_name, e.first_name, e.last_name
ORDER BY sb.amount DESC;

-- =============================================================================
-- [SECTION 05.4] - FULL OUTER JOIN (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== FULL OUTER JOIN: KEEP ALL ROWS FROM BOTH TABLES ===

Returns all rows from both tables.
Unmatched rows show NULL for columns from the other table.
Useful for finding data inconsistencies and gaps.
');

DBMS_OUTPUT.PUT_LINE('Full Join: Employees vs. Leave Records (FULL OUTER JOIN):');
DBMS_OUTPUT.PUT_LINE('────────────────────────────────────────────────────────');

SELECT
    COALESCE(e.emp_id, l.emp_id) as emp_id,
    NVL(e.first_name || ' ' || e.last_name, 'ORPHANED LEAVE') as employee_name,
    NVL(d.dept_name, 'UNASSIGNED') as department,
    COALESCE(l.leave_id, 0) as recent_leave_count,
    NVL(l.leave_type, 'N/A') as leave_type,
    NVL(TO_CHAR(l.leave_start, 'YYYY-MM-DD'), 'Never') as last_leave_start
FROM EMPLOYEE e
FULL OUTER JOIN LEAVE l ON e.emp_id = l.emp_id
LEFT OUTER JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
ORDER BY COALESCE(e.emp_id, l.emp_id);

-- =============================================================================
-- [SECTION 05.5] - MULTI-TABLE INNER JOIN (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== MULTI-TABLE JOIN: EMPLOYEE/DEPARTMENT/SALARY/PAYROLL ===

Connecting 4 tables to get complete employee compensation view.
');

DBMS_OUTPUT.PUT_LINE('Complete Employee Profile (Department, Salary, Payroll):');
DBMS_OUTPUT.PUT_LINE('─────────────────────────────────────────────────────');

SELECT
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    e.gender,
    e.age,
    d.dept_name,
    sb.amount as monthly_salary,
    sb.bonus_amount,
    COUNT(p.payroll_id) as payroll_records,
    ROUND(SUM(p.gross_amount), 2) as total_gross_paid,
    ROUND(SUM(p.deductions), 2) as total_deductions,
    ROUND(SUM(p.net_amount), 2) as total_net_paid
FROM EMPLOYEE e
INNER JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
INNER JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
LEFT OUTER JOIN PAYROLL p ON e.emp_id = p.emp_id
GROUP BY
    e.emp_id, e.first_name, e.last_name, e.gender, e.age,
    d.dept_name, sb.amount, sb.bonus_amount
ORDER BY d.dept_name, e.first_name;

-- =============================================================================
-- [SECTION 05.6] - JOIN WITH AGGREGATION (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== JOIN WITH GROUP BY & AGGREGATES ===

Combine joins with grouping for department-level analysis.
');

DBMS_OUTPUT.PUT_LINE('Department Payroll Summary (Joined + Aggregated):');
DBMS_OUTPUT.PUT_LINE('──────────────────────────────────────────────');

SELECT
    d.dept_name,
    d.salary_range,
    COUNT(DISTINCT e.emp_id) as headcount,
    COUNT(DISTINCT sb.salary_id) as distinct_salary_levels,
    ROUND(AVG(sb.amount), 2) as avg_salary,
    ROUND(MIN(sb.amount), 2) as min_salary,
    ROUND(MAX(sb.amount), 2) as max_salary,
    ROUND(SUM(SUM(p.net_amount)) OVER (PARTITION BY d.dept_name), 2) as dept_net_payroll
FROM JOB_DEPARTMENT d
LEFT OUTER JOIN EMPLOYEE e ON d.job_id = e.job_id
LEFT OUTER JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
LEFT OUTER JOIN PAYROLL p ON e.emp_id = p.emp_id
GROUP BY d.job_id, d.dept_name, d.salary_range
ORDER BY dept_net_payroll DESC;

-- =============================================================================
-- [SECTION 05.7] - SELF JOIN: MANAGER-SUBORDINATE HIERARCHY (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== SELF JOIN: HIERARCHICAL RELATIONSHIPS ===

Joining a table to itself to show hierarchical relationships.
Example: Employees and Approvers (manager).
');

DBMS_OUTPUT.PUT_LINE('Approval Chain: Leave Approvers (SELF JOIN):');
DBMS_OUTPUT.PUT_LINE('────────────────────────────────────────────');

SELECT
    DISTINCT
    l.leave_id,
    e.first_name || ' ' || e.last_name as employee_requesting,
    e.emp_id as emp_requesting,
    mgr.first_name || ' ' || mgr.last_name as approving_manager,
    l.approved_by as mgr_id,
    l.leave_type,
    l.leave_start,
    l.status
FROM LEAVE l
INNER JOIN EMPLOYEE e ON l.emp_id = e.emp_id
INNER JOIN EMPLOYEE mgr ON l.approved_by = mgr.emp_id
ORDER BY l.status, l.leave_start DESC;

-- =============================================================================
-- [SECTION 05.8] - JOIN WITH QUALIFICATION (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== JOIN WITH QUALIFICATION TABLE ===

Show employee qualifications with department context.
');

DBMS_OUTPUT.PUT_LINE('Employees and Their Certifications:');
DBMS_OUTPUT.PUT_LINE('────────────────────────────────');

SELECT
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    q.qual_title,
    q.qual_type,
    TO_CHAR(q.grant_date, 'YYYY-MM-DD') as grant_date,
    DATEDIFF(MONTH, q.grant_date, SYSDATE) as months_since_certification
FROM EMPLOYEE e
INNER JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
LEFT OUTER JOIN QUALIFICATION q ON e.emp_id = q.emp_id
ORDER BY d.dept_name, e.first_name, q.grant_date DESC;

-- =============================================================================
-- [SECTION 05.9] - CROSS JOIN (Cartesian Product) - Medium Task
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== CROSS JOIN: CARTESIAN PRODUCT ===

Returns all possible combinations of rows from both tables.
Use case: Assignment matrices, all possible pairings.
');

DBMS_OUTPUT.PUT_LINE('Department-Salary Cross Reference (Sample - First 10):');
DBMS_OUTPUT.PUT_LINE('──────────────────────────────────────────────────────');

SELECT
    d.dept_name,
    sb.amount as monthly_salary,
    sb.bonus_amount,
    'Dept-Salary Combination ' || d.job_id || '-' || sb.salary_id as combination_id
FROM JOB_DEPARTMENT d
CROSS JOIN SALARY_BONUS sb
WHERE d.job_id <= 3 AND sb.salary_id <= 102
ORDER BY d.dept_name, sb.amount DESC;

-- =============================================================================
-- [SECTION 05.10] - ANTI JOIN (NOT EXISTS) (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== ANTI JOIN: ROWS WITHOUT MATCH ===

Shows rows from one table that have NO match in another.
Use case: Find employees with no payroll record, no qualifications, etc.
');

DBMS_OUTPUT.PUT_LINE('Employees with NO Leave Records (ANTI JOIN - NOT EXISTS):');
DBMS_OUTPUT.PUT_LINE('───────────────────────────────────────────────────────');

SELECT
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    e.hire_date,
    'No leaves on record' as status
FROM EMPLOYEE e
INNER JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
WHERE NOT EXISTS (
    SELECT 1 FROM LEAVE l WHERE l.emp_id = e.emp_id
)
ORDER BY e.hire_date;

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
Employees with NO Qualifications (ANTI JOIN):');

SELECT
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    'No certifications' as qual_status
FROM EMPLOYEE e
INNER JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
WHERE NOT EXISTS (
    SELECT 1 FROM QUALIFICATION q WHERE q.emp_id = e.emp_id
)
ORDER BY e.first_name;

-- =============================================================================
-- [SECTION 05.11] - COMPARISON OF ALL JOIN TYPES (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  JOIN TYPES SUMMARY & COMPARISON
═══════════════════════════════════════════════════════════════════════════
');

DBMS_OUTPUT.PUT_LINE('
Example: Table A (EMPLOYEE) LEFT/RIGHT/FULL JOIN Table B (LEAVE)

INNER JOIN      → Only matching rows (A ∩ B)
LEFT JOIN       → All A + matching B (A + matching B)
RIGHT JOIN      → Matching A + all B (matching A + B)
FULL OUTER JOIN → All A + all B (A ∪ B)
CROSS JOIN      → Every A paired with every B (A × B)
ANTI JOIN       → A rows with no match in B (A - B)
SEMI JOIN       → A rows with match in B (equivalent to INNER JOIN, but distinct)

Performance Tip:
  ✓ INNER JOINs are fastest (reduces rows early)
  ✓ LEFT JOINs are relatively fast
  ✓ FULL OUTER JOINs can be slower (must check both directions)
  ✓ CROSS JOINs produce large result sets - use carefully

Data Quality Check using JOINs:
  • Use ANTI JOINs to find orphaned records
  • Use FULL JOINs to identify data inconsistencies
  • Use NOT EXISTS/IN for complex filtering
');

-- =============================================================================
-- [SECTION 05.12] - DATA INTEGRITY CHECKS VIA JOINs (Hard Task)
-- =============================================================================

DECLARE
    v_emp_with_salary    NUMBER;
    v_emp_without_salary NUMBER;
    v_emp_with_dept      NUMBER;
    v_emp_without_dept   NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '
═══════════════════════════════════════════════════════════════════════════
  DATA INTEGRITY VERIFICATION VIA JOINS
═══════════════════════════════════════════════════════════════════════════
');

    SELECT COUNT(*) INTO v_emp_with_salary
    FROM EMPLOYEE e INNER JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id;

    SELECT COUNT(*) INTO v_emp_without_salary
    FROM EMPLOYEE e WHERE salary_id IS NULL;

    SELECT COUNT(*) INTO v_emp_with_dept
    FROM EMPLOYEE e INNER JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id;

    SELECT COUNT(*) INTO v_emp_without_dept
    FROM EMPLOYEE e WHERE job_id IS NULL;

    DBMS_OUTPUT.PUT_LINE('Total Employees:                ' || (v_emp_with_salary + v_emp_without_salary));
    DBMS_OUTPUT.PUT_LINE('  ✓ Assigned to Salary Grade:   ' || v_emp_with_salary);
    DBMS_OUTPUT.PUT_LINE('  ✗ Missing Salary Assignment:  ' || v_emp_without_salary);
    DBMS_OUTPUT.PUT_LINE('  ✓ Assigned to Department:     ' || v_emp_with_dept);
    DBMS_OUTPUT.PUT_LINE('  ✗ Missing Department:         ' || v_emp_without_dept);

    IF v_emp_without_salary = 0 AND v_emp_without_dept = 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('✓✓✓ ALL EMPLOYEES PROPERLY ASSIGNED ✓✓✓');
    ELSE
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('✗ DATA INTEGRITY ISSUES DETECTED');
    END IF;

    DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  JOIN OPERATIONS COMPLETE
═══════════════════════════════════════════════════════════════════════════');
END;
/

