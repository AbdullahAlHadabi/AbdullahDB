-- =============================================================================
-- 03_dml.sql
-- EMPLOYEE MANAGEMENT SYSTEM (EMS) - DATA MANIPULATION & TRANSACTIONS
-- ORACLE 19c / PL-SQL
-- =============================================================================
-- OBJECTIVE:
--   - Insert realistic sample data (≥10 employees, ≥5 departments)
--   - Demonstrate SAVEPOINT and ROLLBACK for transaction control
--   - Show transaction handling with error recovery
--   - Implement commit checkpoints for data integrity
-- =============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

DBMS_OUTPUT.PUT_LINE('
╔═══════════════════════════════════════════════════════════════════════════╗
║                  EMS DATA INSERTION & TRANSACTION CONTROL                 ║
╚═══════════════════════════════════════════════════════════════════════════╝
');

-- =============================================================================
-- [SECTION 03.1] - POPULATE JOB_DEPARTMENTS (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== INSERTING JOB DEPARTMENTS ===');

INSERT INTO JOB_DEPARTMENT (dept_name, dept_description, salary_range)
VALUES ('Engineering', 'Software Development and Infrastructure', '75K-150K');

INSERT INTO JOB_DEPARTMENT (dept_name, dept_description, salary_range)
VALUES ('Human Resources', 'Employee Relations and Recruitment', '50K-90K');

INSERT INTO JOB_DEPARTMENT (dept_name, dept_description, salary_range)
VALUES ('Finance', 'Accounting and Financial Planning', '60K-120K');

INSERT INTO JOB_DEPARTMENT (dept_name, dept_description, salary_range)
VALUES ('Operations', 'Business Process and Administration', '45K-85K');

INSERT INTO JOB_DEPARTMENT (dept_name, dept_description, salary_range)
VALUES ('Marketing', 'Brand and Digital Marketing', '55K-100K');

DBMS_OUTPUT.PUT_LINE('✓ Inserted 5 Job Departments');

-- =============================================================================
-- [SECTION 03.2] - POPULATE SALARY_BONUS (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== INSERTING SALARY STRUCTURES ===');

-- Engineering salaries
INSERT INTO SALARY_BONUS (amount, bonus_amount, annual_increase, job_id)
VALUES (95000, 9500, 7.5, 1);

INSERT INTO SALARY_BONUS (amount, bonus_amount, annual_increase, job_id)
VALUES (75000, 6000, 5, 1);

-- HR salaries
INSERT INTO SALARY_BONUS (amount, bonus_amount, annual_increase, job_id)
VALUES (65000, 4000, 4, 2);

-- Finance salaries
INSERT INTO SALARY_BONUS (amount, bonus_amount, annual_increase, job_id)
VALUES (85000, 7000, 6, 3);

INSERT INTO SALARY_BONUS (amount, bonus_amount, annual_increase, job_id)
VALUES (65000, 4500, 4.5, 3);

-- Operations salaries
INSERT INTO SALARY_BONUS (amount, bonus_amount, annual_increase, job_id)
VALUES (55000, 3500, 4, 4);

-- Marketing salaries
INSERT INTO SALARY_BONUS (amount, bonus_amount, annual_increase, job_id)
VALUES (70000, 5000, 5, 5);

INSERT INTO SALARY_BONUS (amount, bonus_amount, annual_increase, job_id)
VALUES (60000, 3500, 4, 5);

DBMS_OUTPUT.PUT_LINE('✓ Inserted 8 Salary Structures');

-- =============================================================================
-- [SECTION 03.3] - POPULATE EMPLOYEES (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== INSERTING EMPLOYEES ===');

-- Engineering team
INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('John', 'Doe', 'M', 35, 'john.doe@ems.com', '555-0101', 1, 100);

INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('Jane', 'Smith', 'F', 32, 'jane.smith@ems.com', '555-0102', 1, 101);

INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('Michael', 'Johnson', 'M', 28, 'michael.j@ems.com', '555-0103', 1, 101);

-- HR team
INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('Sarah', 'Williams', 'F', 40, 'sarah.w@ems.com', '555-0104', 2, 102);

INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('Robert', 'Brown', 'M', 38, 'robert.b@ems.com', '555-0105', 2, 102);

-- Finance team
INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('Emily', 'Davis', 'F', 34, 'emily.d@ems.com', '555-0106', 3, 103);

INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('David', 'Miller', 'M', 45, 'david.m@ems.com', '555-0107', 3, 104);

INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('Lisa', 'Wilson', 'F', 29, 'lisa.w@ems.com', '555-0108', 3, 104);

-- Operations team
INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('James', 'Taylor', 'M', 36, 'james.t@ems.com', '555-0109', 4, 105);

INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('Patricia', 'Anderson', 'F', 31, 'patricia.a@ems.com', '555-0110', 4, 105);

-- Marketing team
INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('Christopher', 'Thomas', 'M', 33, 'christopher.t@ems.com', '555-0111', 5, 106);

INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
VALUES ('Jennifer', 'Jackson', 'F', 27, 'jennifer.j@ems.com', '555-0112', 5, 107);

DBMS_OUTPUT.PUT_LINE('✓ Inserted 12 Employees');

-- =============================================================================
-- [SECTION 03.4] - POPULATE QUALIFICATIONS (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== INSERTING QUALIFICATIONS ===');

-- Engineering qualifications
INSERT INTO QUALIFICATION (qual_title, qual_type, grant_date, emp_id)
VALUES ('Bachelor of Science in Computer Science', 'DEGREE', TO_DATE('2010-06-15', 'YYYY-MM-DD'), 1000);

INSERT INTO QUALIFICATION (qual_title, qual_type, grant_date, emp_id)
VALUES ('AWS Solutions Architect', 'CERTIFICATION', TO_DATE('2021-03-20', 'YYYY-MM-DD'), 1000);

INSERT INTO QUALIFICATION (qual_title, qual_type, grant_date, emp_id)
VALUES ('Master of Business Administration', 'DEGREE', TO_DATE('2012-05-10', 'YYYY-MM-DD'), 1001);

INSERT INTO QUALIFICATION (qual_title, qual_type, grant_date, emp_id)
VALUES ('Oracle Database Administrator', 'CERTIFICATION', TO_DATE('2020-11-15', 'YYYY-MM-DD'), 1002);

-- Finance qualifications
INSERT INTO QUALIFICATION (qual_title, qual_type, grant_date, emp_id)
VALUES ('Chartered Financial Analyst (CFA)', 'CERTIFICATION', TO_DATE('2018-09-22', 'YYYY-MM-DD'), 1005);

INSERT INTO QUALIFICATION (qual_title, qual_type, grant_date, emp_id)
VALUES ('Bachelor of Commerce', 'DEGREE', TO_DATE('2008-04-30', 'YYYY-MM-DD'), 1006);

-- HR qualifications
INSERT INTO QUALIFICATION (qual_title, qual_type, grant_date, emp_id)
VALUES ('Human Resource Management Certificate', 'CERTIFICATION', TO_DATE('2019-07-14', 'YYYY-MM-DD'), 1003);

INSERT INTO QUALIFICATION (qual_title, qual_type, grant_date, emp_id)
VALUES ('SHRM Certified Professional', 'CERTIFICATION', TO_DATE('2022-01-25', 'YYYY-MM-DD'), 1004);

DBMS_OUTPUT.PUT_LINE('✓ Inserted 8 Qualifications');

-- =============================================================================
-- [SECTION 03.5] - POPULATE LEAVES (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== INSERTING LEAVE RECORDS ===');

INSERT INTO LEAVE (leave_type, leave_start, leave_end, reason, status, emp_id, approved_by)
VALUES ('SICK', TO_DATE('2024-01-15', 'YYYY-MM-DD'), TO_DATE('2024-01-17', 'YYYY-MM-DD'), 'Flu', 'APPROVED', 1000, 1003);

INSERT INTO LEAVE (leave_type, leave_start, leave_end, reason, status, emp_id, approved_by)
VALUES ('VACATION', TO_DATE('2024-02-10', 'YYYY-MM-DD'), TO_DATE('2024-02-20', 'YYYY-MM-DD'), 'Family trip', 'APPROVED', 1001, 1003);

INSERT INTO LEAVE (leave_type, leave_start, reason, status, emp_id, approved_by)
VALUES ('SICK', TO_DATE('2024-03-05', 'YYYY-MM-DD'), 'Medical appointment', 'PENDING', 1005, 1003);

INSERT INTO LEAVE (leave_type, leave_start, leave_end, reason, status, emp_id, approved_by)
VALUES ('VACATION', TO_DATE('2024-04-01', 'YYYY-MM-DD'), TO_DATE('2024-04-15', 'YYYY-MM-DD'), 'Summer vacation', 'APPROVED', 1006, 1003);

DBMS_OUTPUT.PUT_LINE('✓ Inserted 4 Leave Records');

COMMIT;
DBMS_OUTPUT.PUT_LINE(CHR(10) || '✓ Phase 1 Committed: Base data inserted');

-- =============================================================================
-- [SECTION 03.6] - TRANSACTION CONTROL WITH SAVEPOINT (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  TRANSACTION DEMO: SAVEPOINT & ROLLBACK (Error Recovery)
═══════════════════════════════════════════════════════════════════════════
');

DECLARE
    v_emp_id        NUMBER;
    v_payroll_id    NUMBER;
    v_net_salary    NUMBER;

BEGIN
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '→ TRANSACTION INITIATED');
    DBMS_OUTPUT.PUT_LINE('─ Processing payroll for Employee ID 1000 (John Doe)');

    -- Insert a valid payroll entry
    INSERT INTO PAYROLL (payroll_date, gross_amount, deductions, net_amount, emp_id, job_id, salary_id, payment_status)
    VALUES (SYSDATE, 95000, 19000, 76000, 1000, 1, 100, 'PENDING')
    RETURNING payroll_id INTO v_payroll_id;

    DBMS_OUTPUT.PUT_LINE('✓ Valid Payroll Record Created (ID: ' || v_payroll_id || ')');
    DBMS_OUTPUT.PUT_LINE('  Gross: $95,000 | Deductions: $19,000 | Net: $76,000');

    -- Create a SAVEPOINT before risky operation
    SAVEPOINT before_second_payroll;
    DBMS_OUTPUT.PUT_LINE('✓ SAVEPOINT "before_second_payroll" created');

    -- Attempt to insert invalid payroll (negative net salary - data quality check)
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '→ Attempting to insert INVALID payroll record...');
    DBMS_OUTPUT.PUT_LINE('  (This intentionally violates business logic)');

    BEGIN
        -- This would fail with CHECK constraint or business logic
        INSERT INTO PAYROLL (payroll_date, gross_amount, deductions, net_amount, emp_id, job_id, salary_id, payment_status)
        VALUES (SYSDATE, 50000, 60000, -10000, 1000, 1, 100, 'PROCESSING');

        DBMS_OUTPUT.PUT_LINE('✗ Invalid record inserted - this should not happen!');

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('✗ ERROR DETECTED: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('  Code: ' || SQLCODE);
            DBMS_OUTPUT.PUT_LINE('✓ Rolling back to SAVEPOINT...');

            -- Rollback to the savepoint - keeps the valid payroll record
            ROLLBACK TO before_second_payroll;
            DBMS_OUTPUT.PUT_LINE('✓ Rollback successful - invalid changes discarded');
    END;

    -- Now insert a corrected payroll record
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '→ Inserting CORRECTED payroll record...');

    INSERT INTO PAYROLL (payroll_date, gross_amount, deductions, net_amount, emp_id, job_id, salary_id, payment_status)
    VALUES (SYSDATE + 1, 95000, 19000, 76000, 1000, 1, 100, 'PAID')
    RETURNING payroll_id INTO v_payroll_id;

    DBMS_OUTPUT.PUT_LINE('✓ Corrected Payroll Record Created (ID: ' || v_payroll_id || ')');
    DBMS_OUTPUT.PUT_LINE('  Gross: $95,000 | Deductions: $19,000 | Net: $76,000');

    -- Final COMMIT
    COMMIT;
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '✓ TRANSACTION COMMITTED');
    DBMS_OUTPUT.PUT_LINE('  All valid changes persisted to database');

    DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  TRANSACTION SUMMARY:
  ✓ Valid record KEPT (not rolled back)
  ✓ Invalid record REJECTED (rolled back to savepoint)
  ✓ Corrected record INSERTED (then committed)
  ✓ Database integrity MAINTAINED
═══════════════════════════════════════════════════════════════════════════
    ');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ FATAL ERROR: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END;
/

-- =============================================================================
-- [SECTION 03.7] - BULK PAYROLL INSERT WITH BATCH COMMIT (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== BULK PAYROLL DATA INSERT ===');

DECLARE
    TYPE t_payroll_rec IS RECORD (
        emp_id      NUMBER,
        job_id      NUMBER,
        salary_id   NUMBER,
        gross_amt   NUMBER
    );

    TYPE t_payroll_table IS TABLE OF t_payroll_rec;
    v_payroll_data t_payroll_table;
    v_batch_count  NUMBER := 0;

BEGIN
    -- Load payroll data for all 12 employees
    v_payroll_data := t_payroll_table(
        t_payroll_rec(1000, 1, 100, 95000),
        t_payroll_rec(1001, 1, 101, 75000),
        t_payroll_rec(1002, 1, 101, 75000),
        t_payroll_rec(1003, 2, 102, 65000),
        t_payroll_rec(1004, 2, 102, 65000),
        t_payroll_rec(1005, 3, 103, 85000),
        t_payroll_rec(1006, 3, 104, 65000),
        t_payroll_rec(1007, 3, 104, 65000),
        t_payroll_rec(1008, 4, 105, 55000),
        t_payroll_rec(1009, 4, 105, 55000),
        t_payroll_rec(1010, 5, 106, 70000),
        t_payroll_rec(1011, 5, 107, 60000)
    );

    -- Insert with BATCH processing
    FOR i IN v_payroll_data.FIRST .. v_payroll_data.LAST LOOP
        INSERT INTO PAYROLL (
            payroll_date,
            gross_amount,
            deductions,
            net_amount,
            emp_id,
            job_id,
            salary_id,
            payment_status
        ) VALUES (
            TRUNC(SYSDATE),
            v_payroll_data(i).gross_amt,
            v_payroll_data(i).gross_amt * 0.20,  -- 20% deduction
            v_payroll_data(i).gross_amt * 0.80,  -- 80% net
            v_payroll_data(i).emp_id,
            v_payroll_data(i).job_id,
            v_payroll_data(i).salary_id,
            'PROCESSED'
        );

        v_batch_count := v_batch_count + 1;

        -- Commit every 5 records for memory efficiency
        IF MOD(v_batch_count, 5) = 0 THEN
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('✓ Batch ' || CEIL(v_batch_count/5) || ' committed (' || v_batch_count || ' records)');
        END IF;
    END LOOP;

    -- Commit remaining records
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ Final batch committed');
    DBMS_OUTPUT.PUT_LINE('✓ Total ' || v_batch_count || ' payroll records inserted');

END;
/

-- =============================================================================
-- [SECTION 03.8] - DATA VERIFICATION (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== DATA VERIFICATION ===');

DECLARE
    v_emp_count         NUMBER;
    v_dept_count        NUMBER;
    v_payroll_count     NUMBER;
    v_leave_count       NUMBER;
    v_qualification_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_emp_count FROM EMPLOYEE;
    SELECT COUNT(*) INTO v_dept_count FROM JOB_DEPARTMENT;
    SELECT COUNT(*) INTO v_payroll_count FROM PAYROLL;
    SELECT COUNT(*) INTO v_leave_count FROM LEAVE;
    SELECT COUNT(*) INTO v_qualification_count FROM QUALIFICATION;

    DBMS_OUTPUT.PUT_LINE('Total Employees:        ' || v_emp_count || ' ✓');
    DBMS_OUTPUT.PUT_LINE('Total Departments:      ' || v_dept_count || ' ✓');
    DBMS_OUTPUT.PUT_LINE('Total Payroll Records:  ' || v_payroll_count || ' ✓');
    DBMS_OUTPUT.PUT_LINE('Total Leave Records:    ' || v_leave_count || ' ✓');
    DBMS_OUTPUT.PUT_LINE('Total Qualifications:   ' || v_qualification_count || ' ✓');

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '═══════════════════════════════════════════');
    DBMS_OUTPUT.PUT_LINE('  DML OPERATIONS COMPLETE');
    DBMS_OUTPUT.PUT_LINE('═══════════════════════════════════════════');
END;
/

COMMIT;

