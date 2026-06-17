-- =============================================================================
-- 04_aggregation.sql
-- EMPLOYEE MANAGEMENT SYSTEM (EMS) - AGGREGATION & ANALYTICS
-- ORACLE 19c / PL-SQL
-- =============================================================================
-- OBJECTIVE:
--   - Demonstrate GROUP BY with ROLLUP for subtotals and grand totals
--   - Show analytical functions (DENSE_RANK, ROW_NUMBER, RANK)
--   - Create summary statistics per department
--   - Implement window functions for performance analysis
-- =============================================================================

SET SERVEROUTPUT ON;
SET PAGESIZE 100;

DBMS_OUTPUT.PUT_LINE('
╔═══════════════════════════════════════════════════════════════════════════╗
║              EMS AGGREGATION & ANALYTICAL FUNCTIONS QUERIES              ║
╚═══════════════════════════════════════════════════════════════════════════╝
');

-- =============================================================================
-- [SECTION 04.1] - SIMPLE AGGREGATION (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
=== BASIC AGGREGATIONS ===
');

DBMS_OUTPUT.PUT_LINE('Total Salary Budget by Department:');
DBMS_OUTPUT.PUT_LINE('───────────────────────────────────');

SELECT
    d.dept_name,
    COUNT(e.emp_id) as employee_count,
    SUM(sb.amount) as total_salary,
    AVG(sb.amount) as avg_salary,
    MIN(sb.amount) as min_salary,
    MAX(sb.amount) as max_salary
FROM JOB_DEPARTMENT d
LEFT JOIN EMPLOYEE e ON d.job_id = e.job_id
LEFT JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
GROUP BY d.job_id, d.dept_name
ORDER BY total_salary DESC;

-- =============================================================================
-- [SECTION 04.2] - ROLLUP FOR SUBTOTALS & GRAND TOTALS (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
=== ROLLUP: HIERARCHICAL AGGREGATION ===

ROLLUP produces subtotals at different aggregation levels:
  Level 1: Details for each Department
  Level 2: Grand Total across all Departments
');

DBMS_OUTPUT.PUT_LINE('Department Salary Summary with Subtotals (using ROLLUP):');
DBMS_OUTPUT.PUT_LINE('─────────────────────────────────────────────────────────');

SELECT
    CASE WHEN ROLLUP_ID = 1 THEN 'GRAND TOTAL'
         ELSE d.dept_name
    END as department,
    COUNT(e.emp_id) as headcount,
    ROUND(SUM(sb.amount), 2) as salary_budget,
    ROUND(AVG(sb.amount), 2) as avg_salary,
    CASE WHEN ROLLUP_ID = 1 THEN 'COMPANY WIDE'
         ELSE 'Department'
    END as level_type
FROM JOB_DEPARTMENT d
LEFT JOIN EMPLOYEE e ON d.job_id = e.job_id
LEFT JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
GROUP BY ROLLUP(d.dept_name)
ORDER BY department;

-- =============================================================================
-- [SECTION 04.3] - CUBE FOR MULTI-DIMENSIONAL ANALYSIS (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
=== CUBE: MULTI-DIMENSIONAL ANALYSIS ===

CUBE generates all possible combinations of aggregation levels.
Useful for cross-tabular analysis (e.g., salary by department AND gender).
');

DBMS_OUTPUT.PUT_LINE('Salary Analysis by Department and Gender (using CUBE):');
DBMS_OUTPUT.PUT_LINE('──────────────────────────────────────────────────────');

SELECT
    NVL(d.dept_name, 'TOTAL') as department,
    NVL(e.gender, 'BOTH') as gender,
    COUNT(e.emp_id) as employee_count,
    ROUND(SUM(sb.amount), 2) as total_salary,
    ROUND(AVG(sb.amount), 2) as avg_salary
FROM JOB_DEPARTMENT d
LEFT JOIN EMPLOYEE e ON d.job_id = e.job_id
LEFT JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
GROUP BY CUBE(d.dept_name, e.gender)
ORDER BY department, gender;

-- =============================================================================
-- [SECTION 04.4] - DENSE_RANK ANALYTICAL FUNCTION (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
=== DENSE_RANK: RANK WITHOUT GAPS ===

DENSE_RANK() ranks rows without skipping rank numbers.
Useful for top-N queries (e.g., "Top 3 earners per department").
');

DBMS_OUTPUT.PUT_LINE('Employee Rankings by Salary (Within Each Department):');
DBMS_OUTPUT.PUT_LINE('────────────────────────────────────────────────────');

SELECT
    d.dept_name,
    e.first_name || ' ' || e.last_name as employee_name,
    sb.amount as monthly_salary,
    DENSE_RANK() OVER (PARTITION BY d.dept_name ORDER BY sb.amount DESC) as salary_rank,
    ROUND(100 * sb.amount / SUM(sb.amount)
        OVER (PARTITION BY d.dept_name), 2) as pct_of_dept_salary
FROM EMPLOYEE e
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
ORDER BY d.dept_name, salary_rank;

-- =============================================================================
-- [SECTION 04.5] - ROW_NUMBER & RANK COMPARISON (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
=== RANK FUNCTIONS COMPARISON ===

Three ranking functions with different tie-handling:
  • ROW_NUMBER(): Sequential numbers (may differ for ties)
  • RANK():       Gaps in sequence when ties occur
  • DENSE_RANK(): No gaps in sequence
');

DBMS_OUTPUT.PUT_LINE('Salary Ranking Comparison (All Employees, All Functions):');
DBMS_OUTPUT.PUT_LINE('───────────────────────────────────────────────────────');

SELECT
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    sb.amount as salary,
    ROW_NUMBER() OVER (ORDER BY sb.amount DESC) as row_num,
    RANK() OVER (ORDER BY sb.amount DESC) as rank,
    DENSE_RANK() OVER (ORDER BY sb.amount DESC) as dense_rank
FROM EMPLOYEE e
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
WHERE DENSE_RANK() OVER (ORDER BY sb.amount DESC) <= 5
ORDER BY salary DESC;

-- =============================================================================
-- [SECTION 04.6] - LEAD & LAG WINDOW FUNCTIONS (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
=== LEAD & LAG: COMPARE ROWS ===

LEAD(): Access data from subsequent rows
LAG():  Access data from previous rows

Use case: Salary progression analysis, anomaly detection.
');

DBMS_OUTPUT.PUT_LINE('Salary Gaps Analysis (Sort by Salary, Show Previous/Next):');
DBMS_OUTPUT.PUT_LINE('─────────────────────────────────────────────────────────');

SELECT
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    sb.amount as salary,
    LAG(sb.amount) OVER (ORDER BY sb.amount DESC) as prev_higher_salary,
    LEAD(sb.amount) OVER (ORDER BY sb.amount DESC) as next_lower_salary,
    ROUND(sb.amount - LAG(sb.amount) OVER (ORDER BY sb.amount DESC), 2) as gap_from_higher,
    ROUND(LEAD(sb.amount) OVER (ORDER BY sb.amount DESC) - sb.amount, 2) as gap_to_lower
FROM EMPLOYEE e
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
ORDER BY salary DESC;

-- =============================================================================
-- [SECTION 04.7] - AGGREGATE FUNCTIONS WITH WINDOW (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
=== MOVING AGGREGATES (WINDOW FRAMES) ===

Calculate running totals and moving averages across ordered rows.
');

DBMS_OUTPUT.PUT_LINE('Salary Running Total (Ordered by Amount):');
DBMS_OUTPUT.PUT_LINE('────────────────────────────────────────');

SELECT
    e.first_name || ' ' || e.last_name as employee_name,
    sb.amount as salary,
    SUM(sb.amount) OVER (
        ORDER BY sb.amount DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as running_total,
    ROUND(AVG(sb.amount) OVER (
        ORDER BY sb.amount DESC
        ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
    ), 2) as moving_avg_5rows,
    COUNT(*) OVER (
        ORDER BY sb.amount DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as cumulative_count
FROM EMPLOYEE e
JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
ORDER BY salary DESC;

-- =============================================================================
-- [SECTION 04.8] - PAYROLL EXPENSE ANALYSIS (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
=== PAYROLL EXPENSE SUMMARY ===

Total payroll, employee costs, deduction patterns per department.
');

DBMS_OUTPUT.PUT_LINE('Department Payroll Expense Report (with Percentages):');
DBMS_OUTPUT.PUT_LINE('───────────────────────────────────────────────────');

SELECT
    d.dept_name,
    COUNT(DISTINCT p.emp_id) as employees_paid,
    COUNT(p.payroll_id) as payroll_records,
    ROUND(SUM(p.gross_amount), 2) as total_gross,
    ROUND(SUM(p.deductions), 2) as total_deductions,
    ROUND(SUM(p.net_amount), 2) as total_net,
    ROUND(100 * SUM(p.gross_amount) / SUM(SUM(p.gross_amount))
        OVER (), 2) as pct_of_total_payroll,
    ROUND(AVG(p.net_amount), 2) as avg_net_payment
FROM PAYROLL p
JOIN JOB_DEPARTMENT d ON p.job_id = d.job_id
GROUP BY d.job_id, d.dept_name
ORDER BY total_gross DESC;

-- =============================================================================
-- [SECTION 04.9] - LEAVE STATISTICS BY DEPARTMENT (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
=== LEAVE ANALYSIS BY DEPARTMENT ===
');

DBMS_OUTPUT.PUT_LINE('Leave Days by Department and Type:');
DBMS_OUTPUT.PUT_LINE('──────────────────────────────────');

SELECT
    d.dept_name,
    l.leave_type,
    COUNT(*) as leave_count,
    COUNT(DISTINCT l.emp_id) as employees_on_leave,
    ROUND(AVG(NVL(l.leave_end - l.leave_start, 0)), 1) as avg_duration_days
FROM LEAVE l
JOIN EMPLOYEE e ON l.emp_id = e.emp_id
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
GROUP BY ROLLUP(d.dept_name, l.leave_type)
ORDER BY d.dept_name, l.leave_type;

-- =============================================================================
-- [SECTION 04.10] - QUALIFICATION STATISTICS (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '
=== QUALIFICATION DISTRIBUTION ===
');

DBMS_OUTPUT.PUT_LINE('Certifications vs. Degrees by Department:');
DBMS_OUTPUT.PUT_LINE('─────────────────────────────────────────');

SELECT
    d.dept_name,
    q.qual_type,
    COUNT(*) as count,
    COUNT(DISTINCT q.emp_id) as unique_employees
FROM QUALIFICATION q
JOIN EMPLOYEE e ON q.emp_id = e.emp_id
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
GROUP BY d.dept_name, q.qual_type
ORDER BY d.dept_name, q.qual_type;

-- =============================================================================
-- [SECTION 04.11] - SUMMARY STATISTICS VIEW (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  FINAL SUMMARY: KEY METRICS
═══════════════════════════════════════════════════════════════════════════
');

DECLARE
    v_total_employees    NUMBER;
    v_total_salary       NUMBER;
    v_avg_salary         NUMBER;
    v_total_payroll      NUMBER;
    v_total_deductions   NUMBER;
    v_max_salary         NUMBER;
BEGIN
    SELECT
        COUNT(DISTINCT emp_id),
        ROUND(SUM(amount), 2),
        ROUND(AVG(amount), 2),
        ROUND(SUM(gross_amount), 2),
        ROUND(SUM(deductions), 2),
        MAX(amount)
    INTO
        v_total_employees,
        v_total_salary,
        v_avg_salary,
        v_total_payroll,
        v_total_deductions,
        v_max_salary
    FROM (
        SELECT DISTINCT emp_id, amount FROM EMPLOYEE e JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
    ),
    PAYROLL;

    DBMS_OUTPUT.PUT_LINE('Employees on Payroll:      ' || v_total_employees);
    DBMS_OUTPUT.PUT_LINE('Total Annual Salary Budget: $' || v_total_salary);
    DBMS_OUTPUT.PUT_LINE('Average Salary:            $' || v_avg_salary);
    DBMS_OUTPUT.PUT_LINE('Total Payroll Processed:   $' || v_total_payroll);
    DBMS_OUTPUT.PUT_LINE('Total Deductions:          $' || v_total_deductions);
    DBMS_OUTPUT.PUT_LINE('Max Salary:                $' || v_max_salary);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('═══════════════════════════════════════════════════════════════════════════════════');
    DBMS_OUTPUT.PUT_LINE('  AGGREGATION & ANALYTICS COMPLETE');
    DBMS_OUTPUT.PUT_LINE('═══════════════════════════════════════════════════════════════════════════════════');

END;
/

