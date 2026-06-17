-- =============================================================================
-- 07_views.sql
-- EMPLOYEE MANAGEMENT SYSTEM (EMS) - VIEWS & MATERIALIZED VIEWS
-- ORACLE 19c / PL-SQL
-- =============================================================================
-- OBJECTIVE:
--   - Create simple views for data abstraction and security
--   - Create complex views combining multiple tables
--   - Create Materialized Views for reporting and performance
--   - Implement view refresh strategies (COMPLETE, FAST, ON DEMAND)
-- =============================================================================

SET SERVEROUTPUT ON;

DBMS_OUTPUT.PUT_LINE('
╔═══════════════════════════════════════════════════════════════════════════╗
║                     EMS VIEWS & MATERIALIZED VIEWS                        ║
╚═══════════════════════════════════════════════════════════════════════════╝
');

-- =============================================================================
-- [SECTION 07.1] - CLEAN UP EXISTING VIEWS (Idempotent)
-- =============================================================================

BEGIN
    -- Drop views in dependency order
    FOR v IN (SELECT view_name FROM user_views
              WHERE view_name LIKE 'VW_%' OR view_name LIKE 'MVW_%') LOOP
        EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name || ' CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('Dropped view: ' || v.view_name);
    END LOOP;

    -- Drop materialized views
    FOR v IN (SELECT mview_name FROM user_mviews
              WHERE mview_name LIKE 'MVW_%') LOOP
        EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW ' || v.mview_name;
        DBMS_OUTPUT.PUT_LINE('Dropped materialized view: ' || v.mview_name);
    END LOOP;

EXCEPTION WHEN OTHERS THEN NULL;
END;
/

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING SIMPLE VIEWS ===');

-- =============================================================================
-- [SECTION 07.2] - SIMPLE VIEWS (Easy Task)
-- =============================================================================

-- VIEW 1: Employee Directory
-- Purpose: Public directory showing basic employee info (masked sensitive data)
CREATE OR REPLACE VIEW VW_EMPLOYEE_DIRECTORY AS
SELECT
    e.emp_id,
    e.first_name,
    e.last_name,
    e.email,
    d.dept_name,
    e.phone,
    e.hire_date
FROM EMPLOYEE e
LEFT JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
WHERE 1 = 1;  -- Can add security filters here

DBMS_OUTPUT.PUT_LINE('✓ Created VW_EMPLOYEE_DIRECTORY (Public directory - masked salary)');

-- VIEW 2: Salary Information
-- Purpose: Finance team only - complete salary and bonus breakdown
CREATE OR REPLACE VIEW VW_SALARY_INFO AS
SELECT
    e.emp_id,
    e.first_name || ' ' || e.last_name as full_name,
    d.dept_name,
    sb.salary_id,
    sb.amount as base_salary,
    sb.bonus_amount,
    sb.annual_increase as annual_increase_pct,
    ROUND(sb.amount + sb.bonus_amount, 2) as total_compensation,
    e.hire_date
FROM EMPLOYEE e
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id;

DBMS_OUTPUT.PUT_LINE('✓ Created VW_SALARY_INFO (Finance reporting view)');

-- VIEW 3: Department Statistics
-- Purpose: HR and management reporting
CREATE OR REPLACE VIEW VW_DEPARTMENT_STATS AS
SELECT
    d.job_id,
    d.dept_name,
    d.dept_description,
    COUNT(e.emp_id) as headcount,
    ROUND(AVG(sb.amount), 2) as avg_salary,
    MIN(sb.amount) as min_salary,
    MAX(sb.amount) as max_salary,
    ROUND(SUM(sb.amount), 2) as total_salary_budget
FROM JOB_DEPARTMENT d
LEFT JOIN EMPLOYEE e ON d.job_id = e.job_id
LEFT JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
GROUP BY d.job_id, d.dept_name, d.dept_description;

DBMS_OUTPUT.PUT_LINE('✓ Created VW_DEPARTMENT_STATS (Management reporting)');

-- =============================================================================
-- [SECTION 07.3] - COMPLEX VIEW WITH MULTIPLE JOINS (Medium Task)
-- =============================================================================

CREATE OR REPLACE VIEW VW_EMPLOYEE_PROFILE AS
SELECT
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    e.gender,
    e.age,
    e.email,
    e.phone,
    e.hire_date,
    d.dept_name,
    d.job_id,
    sb.amount as monthly_salary,
    sb.bonus_amount,
    ROUND(sb.amount + sb.bonus_amount, 2) as total_compensation,
    COUNT(DISTINCT l.leave_id) as total_leave_requests,
    COUNT(DISTINCT q.qual_id) as qualification_count,
    COUNT(DISTINCT p.payroll_id) as payroll_records
FROM EMPLOYEE e
LEFT JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
LEFT JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
LEFT JOIN LEAVE l ON e.emp_id = l.emp_id
LEFT JOIN QUALIFICATION q ON e.emp_id = q.emp_id
LEFT JOIN PAYROLL p ON e.emp_id = p.emp_id
GROUP BY
    e.emp_id, e.first_name, e.last_name, e.gender, e.age, e.email, e.phone,
    e.hire_date, d.dept_name, d.job_id, sb.amount, sb.bonus_amount;

DBMS_OUTPUT.PUT_LINE('✓ Created VW_EMPLOYEE_PROFILE (Comprehensive employee view)');

-- =============================================================================
-- [SECTION 07.4] - COMPLEX VIEW FOR PAYROLL (Hard Task)
-- =============================================================================

CREATE OR REPLACE VIEW VW_PAYROLL_ANALYSIS AS
SELECT
    p.payroll_id,
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    p.payroll_date,
    p.gross_amount,
    p.deductions,
    p.net_amount,
    ROUND(100 * p.deductions / NULLIF(p.gross_amount, 0), 2) as deduction_pct,
    CASE
        WHEN p.payment_status = 'PENDING' THEN 'Awaiting Processing'
        WHEN p.payment_status = 'PROCESSED' THEN 'Ready to Pay'
        WHEN p.payment_status = 'PAID' THEN 'Paid Out'
        ELSE 'Unknown'
    END as payment_status_desc,
    ROUND((p.gross_amount - p.deductions) / 26, 2) as weekly_net,
    TRUNC(SYSDATE) - TRUNC(p.payroll_date) as days_since_payroll
FROM PAYROLL p
JOIN EMPLOYEE e ON p.emp_id = e.emp_id
JOIN JOB_DEPARTMENT d ON p.job_id = d.job_id;

DBMS_OUTPUT.PUT_LINE('✓ Created VW_PAYROLL_ANALYSIS (Payroll reporting)');

-- =============================================================================
-- [SECTION 07.5] - LEAVE MANAGEMENT VIEW (Medium Task)
-- =============================================================================

CREATE OR REPLACE VIEW VW_LEAVE_MANAGEMENT AS
SELECT
    l.leave_id,
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    l.leave_type,
    l.leave_start,
    l.leave_end,
    NVL(TRUNC(l.leave_end - l.leave_start + 1), 1) as days_requested,
    l.reason,
    l.status,
    CASE
        WHEN l.status = 'APPROVED' THEN 'Approved by Manager'
        WHEN l.status = 'PENDING' THEN 'Awaiting Approval'
        WHEN l.status = 'REJECTED' THEN 'Not Approved'
        ELSE 'Unknown'
    END as status_description,
    mgr.first_name || ' ' || mgr.last_name as approved_by_manager,
    TRUNC(SYSDATE) - TRUNC(l.leave_start) as days_until_leave
FROM LEAVE l
JOIN EMPLOYEE e ON l.emp_id = e.emp_id
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
LEFT JOIN EMPLOYEE mgr ON l.approved_by = mgr.emp_id;

DBMS_OUTPUT.PUT_LINE('✓ Created VW_LEAVE_MANAGEMENT (Leave tracking)');

-- =============================================================================
-- [SECTION 07.6] - QUALIFICATION & TRAINING VIEW (Easy Task)
-- =============================================================================

CREATE OR REPLACE VIEW VW_EMPLOYEE_QUALIFICATIONS AS
SELECT
    q.qual_id,
    e.emp_id,
    e.first_name || ' ' || e.last_name as employee_name,
    d.dept_name,
    q.qual_title,
    q.qual_type,
    q.grant_date,
    CEIL((TRUNC(SYSDATE) - TRUNC(q.grant_date)) / 365.25) as years_since_certification,
    CASE
        WHEN CEIL((TRUNC(SYSDATE) - TRUNC(q.grant_date)) / 365.25) >= 3 THEN 'Renewal Recommended'
        WHEN CEIL((TRUNC(SYSDATE) - TRUNC(q.grant_date)) / 365.25) >= 2 THEN 'Current'
        ELSE 'Recent'
    END as certification_status
FROM QUALIFICATION q
JOIN EMPLOYEE e ON q.emp_id = e.emp_id
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id;

DBMS_OUTPUT.PUT_LINE('✓ Created VW_EMPLOYEE_QUALIFICATIONS (Training records)');

-- =============================================================================
-- [SECTION 07.7] - MATERIALIZED VIEW: DEPARTMENT SUMMARY (Hard Task)
-- Purpose: Pre-calculated aggregates for fast reporting
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING MATERIALIZED VIEWS ===');

CREATE MATERIALIZED VIEW MVW_DEPARTMENT_SUMMARY
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    d.job_id,
    d.dept_name,
    d.dept_description,
    COUNT(e.emp_id) as headcount,
    ROUND(AVG(sb.amount), 2) as avg_salary,
    MIN(sb.amount) as min_salary,
    MAX(sb.amount) as max_salary,
    ROUND(SUM(sb.amount), 2) as total_salary_budget,
    COUNT(DISTINCT p.payroll_id) as total_payroll_records,
    ROUND(SUM(p.gross_amount), 2) as total_gross_paid,
    SYSDATE as last_refreshed
FROM JOB_DEPARTMENT d
LEFT JOIN EMPLOYEE e ON d.job_id = e.job_id
LEFT JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
LEFT JOIN PAYROLL p ON e.emp_id = p.emp_id
GROUP BY d.job_id, d.dept_name, d.dept_description;

DBMS_OUTPUT.PUT_LINE('✓ Created MVW_DEPARTMENT_SUMMARY (Pre-calculated aggregates)');

-- =============================================================================
-- [SECTION 07.8] - MATERIALIZED VIEW: MONTHLY PAYROLL (Hard Task)
-- Purpose: Monthly payroll snapshot for compliance and auditing
-- =============================================================================

CREATE MATERIALIZED VIEW MVW_MONTHLY_PAYROLL
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    TRUNC(p.payroll_date, 'MM') as payroll_month,
    d.dept_name,
    COUNT(p.payroll_id) as payroll_records,
    COUNT(DISTINCT p.emp_id) as employees_paid,
    ROUND(SUM(p.gross_amount), 2) as total_gross,
    ROUND(SUM(p.deductions), 2) as total_deductions,
    ROUND(SUM(p.net_amount), 2) as total_net,
    ROUND(AVG(p.net_amount), 2) as avg_net_per_employee,
    MAX(p.payroll_date) as latest_payroll_date
FROM PAYROLL p
JOIN JOB_DEPARTMENT d ON p.job_id = d.job_id
WHERE p.payroll_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
GROUP BY TRUNC(p.payroll_date, 'MM'), d.dept_name;

DBMS_OUTPUT.PUT_LINE('✓ Created MVW_MONTHLY_PAYROLL (Monthly payroll summary)');

-- =============================================================================
-- [SECTION 07.9] - MATERIALIZED VIEW: LEAVE STATISTICS (Hard Task)
-- Purpose: Leave balance and utilization tracking
-- =============================================================================

CREATE MATERIALIZED VIEW MVW_LEAVE_STATISTICS
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    d.dept_name,
    COUNT(DISTINCT l.emp_id) as employees_with_leaves,
    COUNT(l.leave_id) as total_leave_requests,
    SUM(CASE WHEN l.status = 'APPROVED' THEN 1 ELSE 0 END) as approved_count,
    SUM(CASE WHEN l.status = 'PENDING' THEN 1 ELSE 0 END) as pending_count,
    SUM(CASE WHEN l.status = 'REJECTED' THEN 1 ELSE 0 END) as rejected_count,
    SUM(CASE WHEN l.leave_type = 'SICK' THEN 1 ELSE 0 END) as sick_leaves,
    SUM(CASE WHEN l.leave_type = 'VACATION' THEN 1 ELSE 0 END) as vacation_leaves,
    ROUND(AVG(NVL(l.leave_end - l.leave_start + 1, 0)), 2) as avg_leave_duration,
    SYSDATE as last_refreshed
FROM LEAVE l
JOIN EMPLOYEE e ON l.emp_id = e.emp_id
JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
GROUP BY d.dept_name;

DBMS_OUTPUT.PUT_LINE('✓ Created MVW_LEAVE_STATISTICS (Leave analytics)');

-- =============================================================================
-- [SECTION 07.10] - VIEW QUERIES FOR TESTING (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TESTING VIEWS ===');

DBMS_OUTPUT.PUT_LINE('
Sample Query 1: VW_EMPLOYEE_DIRECTORY');
SELECT COUNT(*) as total_employees FROM VW_EMPLOYEE_DIRECTORY;

DBMS_OUTPUT.PUT_LINE('
Sample Query 2: VW_DEPARTMENT_STATS');
SELECT * FROM VW_DEPARTMENT_STATS ORDER BY total_salary_budget DESC;

DBMS_OUTPUT.PUT_LINE('
Sample Query 3: VW_SALARY_INFO (Top 5 earners)');
SELECT full_name, dept_name, total_compensation
FROM VW_SALARY_INFO
ORDER BY total_compensation DESC
FETCH FIRST 5 ROWS ONLY;

-- =============================================================================
-- [SECTION 07.11] - REFRESHING MATERIALIZED VIEWS (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== MATERIALIZING VIEW DATA ===');

BEGIN
    -- Refresh Department Summary MV
    DBMS_MVIEW.REFRESH('MVW_DEPARTMENT_SUMMARY', 'C');
    DBMS_OUTPUT.PUT_LINE('✓ Refreshed MVW_DEPARTMENT_SUMMARY');

    -- Refresh Monthly Payroll MV
    DBMS_MVIEW.REFRESH('MVW_MONTHLY_PAYROLL', 'C');
    DBMS_OUTPUT.PUT_LINE('✓ Refreshed MVW_MONTHLY_PAYROLL');

    -- Refresh Leave Statistics MV
    DBMS_MVIEW.REFRESH('MVW_LEAVE_STATISTICS', 'C');
    DBMS_OUTPUT.PUT_LINE('✓ Refreshed MVW_LEAVE_STATISTICS');

EXCEPTION WHEN OTHERS THEN
    IF SQLCODE != -12008 THEN  -- MV doesn't exist
        DBMS_OUTPUT.PUT_LINE('Note: ' || SQLERRM);
    END IF;
END;
/

-- =============================================================================
-- [SECTION 07.12] - VIEW MAINTENANCE & METADATA (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  VIEW INVENTORY & METADATA
═══════════════════════════════════════════════════════════════════════════
');

DECLARE
    v_view_count    NUMBER;
    v_mview_count   NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_view_count
    FROM user_views
    WHERE view_name LIKE 'VW_%';

    SELECT COUNT(*) INTO v_mview_count
    FROM user_mviews
    WHERE mview_name LIKE 'MVW_%';

    DBMS_OUTPUT.PUT_LINE('Simple Views Created:       ' || v_view_count);
    DBMS_OUTPUT.PUT_LINE('Materialized Views Created: ' || v_mview_count);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('VIEW MAINTENANCE TIPS:');
    DBMS_OUTPUT.PUT_LINE('  ✓ Use ON DEMAND refresh for monthly reports');
    DBMS_OUTPUT.PUT_LINE('  ✓ Use COMPLETE refresh for data consistency');
    DBMS_OUTPUT.PUT_LINE('  ✓ Consider FAST refresh for incremental updates (requires logs)');
    DBMS_OUTPUT.PUT_LINE('  ✓ Grant SELECT on views for row-level security');
    DBMS_OUTPUT.PUT_LINE('  ✓ Document view purpose in view names (VW_, MVW_)');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('═══════════════════════════════════════════════════════════════════════════════════');
    DBMS_OUTPUT.PUT_LINE('  VIEWS & MATERIALIZED VIEWS COMPLETE');
    DBMS_OUTPUT.PUT_LINE('═══════════════════════════════════════════════════════════════════════════════════');

END;
/

COMMIT;

