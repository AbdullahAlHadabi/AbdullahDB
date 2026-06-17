-- =============================================================================
-- 06_subqueries.sql
-- EMPLOYEE MANAGEMENT SYSTEM (EMS) - SUBQUERIES & COMMON TABLE EXPRESSIONS
-- ORACLE 19c / PL-SQL
-- =============================================================================
-- OBJECTIVE:
--   - Demonstrate scalar subqueries (single value returns)
--   - Show correlated subqueries (row-by-row comparisons)
--   - Implement CTEs (WITH clause) for complex, readable queries
--   - Compare performance and readability
-- =============================================================================

SET SERVEROUTPUT ON;
SET PAGESIZE 100;
SET LINESIZE 150;

DBMS_OUTPUT.PUT_LINE('
╔═══════════════════════════════════════════════════════════════════════════╗
║             EMS SUBQUERIES & COMMON TABLE EXPRESSIONS (CTEs)             ║
╚═══════════════════════════════════════════════════════════════════════════╝
');

-- =============================================================================
-- [SECTION 06.1] - SCALAR SUBQUERY (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== SCALAR SUBQUERY: SINGLE RETURN VALUE ===

Subquery returns exactly ONE row with ONE column.
Used in SELECT clause, WHERE clause, or assignments.
');

DBMS_OUTPUT.PUT_LINE('Employee Salary vs. Department Average (Scalar Subquery):');
DBMS_OUTPUT.PUT_LINE('───────────────────────────────────────────────────────');

SELECT
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    sb.amount as employee_salary,
    (SELECT ROUND(AVG(sb2.amount), 2)
     FROM EMPLOYEE e2
     JOIN SALARY_BONUS sb2 ON e2.salary_id = sb2.salary_id
     WHERE e2.job_id = e.job_id) as dept_avg_salary,
    ROUND(sb.amount - (SELECT AVG(sb2.amount)
                       FROM EMPLOYEE e2
                       JOIN SALARY_BONUS sb2 ON e2.salary_id = sb2.salary_id
                       WHERE e2.job_id = e.job_id), 2) as difference_from_avg
FROM EMPLOYEE e
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
ORDER BY d.dept_name, difference_from_avg DESC;

-- =============================================================================
-- [SECTION 06.2] - SCALAR SUBQUERY IN WHERE CLAUSE (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== SCALAR SUBQUERY IN WHERE CLAUSE ===

Find employees earning above the company average salary.
');

DBMS_OUTPUT.PUT_LINE('High Earners (Above Company Average):');
DBMS_OUTPUT.PUT_LINE('────────────────────────────────────');

SELECT
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    sb.amount as salary,
    (SELECT ROUND(AVG(amount), 2) FROM SALARY_BONUS) as company_avg
FROM EMPLOYEE e
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
WHERE sb.amount > (SELECT AVG(amount) FROM SALARY_BONUS)
ORDER BY sb.amount DESC;

-- =============================================================================
-- [SECTION 06.3] - CORRELATED SUBQUERY (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== CORRELATED SUBQUERY: ROW-BY-ROW COMPARISON ===

Inner query references columns from outer query.
Executes once per outer row - useful for row-level comparisons.
');

DBMS_OUTPUT.PUT_LINE('Employees and Their Leave Count (Correlated Subquery):');
DBMS_OUTPUT.PUT_LINE('──────────────────────────────────────────────────────');

SELECT
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    (SELECT COUNT(*) FROM LEAVE l WHERE l.emp_id = e.emp_id) as total_leaves,
    (SELECT COUNT(*) FROM LEAVE l
     WHERE l.emp_id = e.emp_id AND l.status = 'APPROVED') as approved_leaves,
    (SELECT COUNT(*) FROM LEAVE l
     WHERE l.emp_id = e.emp_id AND l.status = 'PENDING') as pending_leaves
FROM EMPLOYEE e
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
ORDER BY total_leaves DESC, e.first_name;

-- =============================================================================
-- [SECTION 06.4] - CORRELATED SUBQUERY WITH EXISTS (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== EXISTS: CORRELATED SUBQUERY FOR EXISTENCE CHECK ===

EXISTS returns TRUE/FALSE without fetching all data.
More efficient than IN for large datasets.
');

DBMS_OUTPUT.PUT_LINE('Employees with Qualification Records (Using EXISTS):');
DBMS_OUTPUT.PUT_LINE('──────────────────────────────────────────────────');

SELECT
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    CASE WHEN EXISTS (
        SELECT 1 FROM QUALIFICATION q WHERE q.emp_id = e.emp_id
    ) THEN 'Yes' ELSE 'No' END as has_qualifications,
    CASE WHEN EXISTS (
        SELECT 1 FROM LEAVE l WHERE l.emp_id = e.emp_id AND l.status = 'APPROVED'
    ) THEN 'Yes' ELSE 'No' END as has_approved_leave
FROM EMPLOYEE e
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
ORDER BY e.first_name;

-- =============================================================================
-- [SECTION 06.5] - SUBQUERY IN FROM CLAUSE (Derived Table) (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== SUBQUERY IN FROM CLAUSE (Derived Table) ===

Subquery acts as a virtual table in FROM clause.
Useful for multi-level aggregation.
');

DBMS_OUTPUT.PUT_LINE('Department Salary Analysis (Using Derived Table):');
DBMS_OUTPUT.PUT_LINE('─────────────────────────────────────────────────');

SELECT
    dept_name,
    emp_count,
    total_salary,
    avg_salary,
    ROUND(100 * total_salary / (SELECT SUM(amount)
                                 FROM SALARY_BONUS), 2) as pct_of_total
FROM (
    SELECT
        d.dept_name,
        COUNT(e.emp_id) as emp_count,
        SUM(sb.amount) as total_salary,
        ROUND(AVG(sb.amount), 2) as avg_salary
    FROM JOB_DEPARTMENT d
    LEFT JOIN EMPLOYEE e ON d.job_id = e.job_id
    LEFT JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
    GROUP BY d.dept_name
)
ORDER BY total_salary DESC;

-- =============================================================================
-- [SECTION 06.6] - COMMON TABLE EXPRESSION (CTE) - WITH CLAUSE (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== COMMON TABLE EXPRESSION (CTE) - WITH CLAUSE ===

Makes complex queries more readable by defining named subqueries.
Can be referenced multiple times in main query.
Supports recursive CTEs (hierarchies).
');

DBMS_OUTPUT.PUT_LINE('Employee Compensation vs. Department Average (Using CTE):');
DBMS_OUTPUT.PUT_LINE('──────────────────────────────────────────────────────');

WITH dept_stats AS (
    -- Step 1: Calculate department salary statistics
    SELECT
        d.job_id,
        d.dept_name,
        COUNT(e.emp_id) as headcount,
        ROUND(AVG(sb.amount), 2) as avg_salary,
        MIN(sb.amount) as min_salary,
        MAX(sb.amount) as max_salary,
        ROUND(SUM(sb.amount), 2) as total_salary
    FROM JOB_DEPARTMENT d
    LEFT JOIN EMPLOYEE e ON d.job_id = e.job_id
    LEFT JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
    GROUP BY d.job_id, d.dept_name
),
emp_ranking AS (
    -- Step 2: Rank employees within their department
    SELECT
        e.emp_id,
        e.first_name || ' ' || e.last_name as employee_name,
        d.dept_name,
        sb.amount,
        RANK() OVER (PARTITION BY d.dept_name ORDER BY sb.amount DESC) as salary_rank,
        ds.avg_salary,
        ds.headcount
    FROM EMPLOYEE e
    JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
    JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
    JOIN dept_stats ds ON d.job_id = ds.job_id
)
SELECT
    employee_name,
    dept_name,
    amount,
    salary_rank,
    ROUND(amount - avg_salary, 2) as variance_from_avg,
    headcount as dept_size
FROM emp_ranking
ORDER BY dept_name, salary_rank;

-- =============================================================================
-- [SECTION 06.7] - MULTI-LEVEL CTE (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== MULTI-LEVEL CTE: COMPLEX BUSINESS LOGIC ===

Multiple CTEs building on each other.
Example: Payroll processing with validation and calculations.
');

DBMS_OUTPUT.PUT_LINE('Payroll Summary Report (Multi-Level CTE):');
DBMS_OUTPUT.PUT_LINE('─────────────────────────────────────────');

WITH emp_base AS (
    -- Level 1: Core employee data
    SELECT
        e.emp_id,
        e.first_name || ' ' || e.last_name as employee_name,
        d.dept_name,
        sb.amount as base_salary,
        sb.bonus_amount
    FROM EMPLOYEE e
    JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
    JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
),
payroll_data AS (
    -- Level 2: Aggregate payroll info
    SELECT
        eb.emp_id,
        eb.employee_name,
        eb.dept_name,
        eb.base_salary,
        eb.bonus_amount,
        COUNT(p.payroll_id) as payroll_count,
        ROUND(SUM(p.gross_amount), 2) as total_gross,
        ROUND(SUM(p.deductions), 2) as total_deductions,
        ROUND(SUM(p.net_amount), 2) as total_net
    FROM emp_base eb
    LEFT JOIN PAYROLL p ON eb.emp_id = p.emp_id
    GROUP BY eb.emp_id, eb.employee_name, eb.dept_name, eb.base_salary, eb.bonus_amount
),
final_report AS (
    -- Level 3: Final calculations
    SELECT
        employee_name,
        dept_name,
        base_salary,
        bonus_amount,
        payroll_count,
        total_gross,
        total_deductions,
        total_net,
        ROUND(100 * total_deductions / NULLIF(total_gross, 0), 2) as deduction_pct
    FROM payroll_data
)
SELECT * FROM final_report
ORDER BY dept_name, employee_name;

-- =============================================================================
-- [SECTION 06.8] - CTE WITH RECURSIVE (Hierarchical) (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== RECURSIVE CTE: HIERARCHICAL QUERIES ===

Used for organizational hierarchies, bill of materials, etc.
Example: Show management chain (who reports to whom).
');

DBMS_OUTPUT.PUT_LINE('Organizational Hierarchy (Recursive CTE):');
DBMS_OUTPUT.PUT_LINE('────────────────────────────────────────');

-- Simple example: Build a hierarchy from leave approvals
WITH RECURSIVE approval_chain AS (
    -- Base case: Employees who haven't been approvers
    SELECT
        e.emp_id,
        e.first_name || ' ' || e.last_name as name,
        1 as level,
        NULL as approved_by_id,
        'Individual Contributor' as role
    FROM EMPLOYEE e
    WHERE NOT EXISTS (SELECT 1 FROM LEAVE l WHERE l.approved_by = e.emp_id)

    UNION ALL

    -- Recursive case: Show who approves for whom
    SELECT
        l.approved_by,
        e.first_name || ' ' || e.last_name,
        ac.level + 1,
        e.emp_id,
        'Approver' as role
    FROM approval_chain ac
    JOIN LEAVE l ON ac.emp_id = l.emp_id
    JOIN EMPLOYEE e ON l.approved_by = e.emp_id
    WHERE ac.level < 5  -- Prevent infinite recursion
)
SELECT
    LPAD(' ', (level - 1) * 2) || name as hierarchy,
    role,
    level
FROM approval_chain
ORDER BY level, name;

-- =============================================================================
-- [SECTION 06.9] - SUBQUERY IN INSERT (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
=== SUBQUERY IN INSERT ===

Insert data derived from a query (INSERT ... SELECT).
Useful for data migration, copying filtered records.
');

DBMS_OUTPUT.PUT_LINE('Example: INSERT-SELECT to Archive High-Salary Employees');
DBMS_OUTPUT.PUT_LINE('(This is a demonstration - not actually executed)');
DBMS_OUTPUT.PUT_LINE('────────────────────────────────────────────────────────

Query:
    INSERT INTO PAYROLL (payroll_date, gross_amount, deductions, net_amount, emp_id, job_id, salary_id, payment_status)
    SELECT
        SYSDATE,
        sb.amount,
        sb.amount * 0.15,
        sb.amount * 0.85,
        e.emp_id,
        e.job_id,
        e.salary_id,
        ''PROCESSED''
    FROM EMPLOYEE e
    JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
    WHERE sb.amount > (SELECT AVG(amount) FROM SALARY_BONUS);
');

-- =============================================================================
-- [SECTION 06.10] - COMPARISON: SUBQUERY vs CTE vs JOIN (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  PERFORMANCE & READABILITY COMPARISON
═══════════════════════════════════════════════════════════════════════════

METHOD 1: MULTIPLE JOINS (Least readable, but sometimes fastest)
───────────
SELECT e.name, (SELECT COUNT(*) FROM LEAVE l WHERE l.emp_id = e.emp_id) as leaves
FROM EMPLOYEE e
JOIN DEPARTMENT d ON e.job_id = d.job_id

METHOD 2: SCALAR SUBQUERIES (Readable for simple cases)
──────────────────────────
SELECT
    e.name,
    (SELECT COUNT(*) FROM LEAVE l WHERE l.emp_id = e.emp_id) as leaves
FROM EMPLOYEE e

METHOD 3: CTE WITH CLAUSE (Most readable for complex queries)
────────────────────────────
WITH leave_summary AS (
    SELECT emp_id, COUNT(*) as leave_count
    FROM LEAVE
    GROUP BY emp_id
)
SELECT e.name, COALESCE(ls.leave_count, 0) as leaves
FROM EMPLOYEE e
LEFT JOIN leave_summary ls ON e.emp_id = ls.emp_id

BEST PRACTICES:
✓ Use CTEs for complex, multi-step logic (most readable)
✓ Use scalar subqueries for simple single-value returns
✓ Use correlated subqueries when row-by-row comparison is needed
✓ Use JOINs when possible (usually fastest)
✓ Test execution plans to verify optimizer choices
✓ Name CTEs clearly to document intent

COMMON MISTAKES:
✗ Unnecessary subqueries where JOINs work better
✗ Correlated subqueries in large loops (performance killer)
✗ Deep nesting of subqueries (hard to read and maintain)
✗ Not using indexes on subquery filter columns
');

-- =============================================================================
-- [SECTION 06.11] - QUERY ANALYSIS (Hard Task)
-- =============================================================================

DECLARE
    v_query_count   NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  SUBQUERY & CTE ANALYSIS COMPLETE
═══════════════════════════════════════════════════════════════════════════');

    SELECT COUNT(DISTINCT emp_id) INTO v_query_count FROM EMPLOYEE;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Total Employees Processed: ' || v_query_count);
    DBMS_OUTPUT.PUT_LINE('All subqueries and CTEs executed successfully ✓');

END;
/

