-- =============================================================================
-- 08_procedures.sql
-- EMPLOYEE MANAGEMENT SYSTEM (EMS) - STORED PROCEDURES, FUNCTIONS & PACKAGES
-- ORACLE 19c / PL-SQL
-- =============================================================================
-- OBJECTIVE:
--   - Create Stored Procedures for business logic
--   - Create Functions for calculated values
--   - Create PL/SQL Package to encapsulate procedures and functions
--   - Demonstrate parameters, error handling, and transaction control
-- =============================================================================

SET SERVEROUTPUT ON;

DBMS_OUTPUT.PUT_LINE('
╔═══════════════════════════════════════════════════════════════════════════╗
║          EMS STORED PROCEDURES, FUNCTIONS & PACKAGES (PL/SQL)            ║
╚═══════════════════════════════════════════════════════════════════════════╝
');

-- =============================================================================
-- [SECTION 08.1] - CLEAN UP EXISTING OBJECTS (Idempotent)
-- =============================================================================

BEGIN
    EXECUTE IMMEDIATE 'DROP PACKAGE PKG_EMS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- =============================================================================
-- [SECTION 08.2] - STANDALONE PROCEDURE: ADD EMPLOYEE (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING STORED PROCEDURES ===');

CREATE OR REPLACE PROCEDURE SP_ADD_EMPLOYEE(
    p_first_name    IN VARCHAR2,
    p_last_name     IN VARCHAR2,
    p_gender        IN CHAR,
    p_age           IN NUMBER,
    p_email         IN VARCHAR2,
    p_phone         IN VARCHAR2,
    p_job_id        IN NUMBER,
    p_salary_id     IN NUMBER,
    p_emp_id        OUT NUMBER
)
AS
    v_error_code    NUMBER;
    v_error_msg     VARCHAR2(500);
BEGIN
    -- Validate input parameters
    IF p_first_name IS NULL OR p_last_name IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'First and Last name are required');
    END IF;

    IF p_gender NOT IN ('M', 'F') THEN
        RAISE_APPLICATION_ERROR(-20002, 'Gender must be M or F');
    END IF;

    IF p_age < 18 OR p_age > 75 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Age must be between 18 and 75');
    END IF;

    -- Insert the employee record
    INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
    VALUES (p_first_name, p_last_name, p_gender, p_age, p_email, p_phone, p_job_id, p_salary_id)
    RETURNING emp_id INTO p_emp_id;

    DBMS_OUTPUT.PUT_LINE('✓ Employee added successfully (ID: ' || p_emp_id || ')');
    COMMIT;

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: Email already exists');
        RAISE;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END SP_ADD_EMPLOYEE;
/

DBMS_OUTPUT.PUT_LINE('✓ Created SP_ADD_EMPLOYEE');

-- =============================================================================
-- [SECTION 08.3] - STANDALONE PROCEDURE: UPDATE SALARY (Medium Task)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SP_UPDATE_SALARY(
    p_salary_id     IN NUMBER,
    p_new_amount    IN NUMBER,
    p_reason        IN VARCHAR2 DEFAULT 'Annual increase'
)
AS
    v_old_amount    NUMBER;
    v_difference    NUMBER;
BEGIN
    -- Retrieve old salary for audit
    SELECT amount INTO v_old_amount
    FROM SALARY_BONUS
    WHERE salary_id = p_salary_id;

    -- Validate new salary is not less than old salary
    IF p_new_amount < v_old_amount THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Salary decrease blocked: ' || v_old_amount || ' -> ' || p_new_amount ||
            '. Use administrator override if needed.');
    END IF;

    v_difference := p_new_amount - v_old_amount;

    -- Update the salary
    UPDATE SALARY_BONUS
    SET amount = p_new_amount
    WHERE salary_id = p_salary_id;

    DBMS_OUTPUT.PUT_LINE('✓ Salary updated: $' || v_old_amount || ' -> $' || p_new_amount);
    DBMS_OUTPUT.PUT_LINE('  Increase: $' || v_difference || ' (' ||
        ROUND(100 * v_difference / v_old_amount, 2) || '%)');

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: Salary ID not found');
        RAISE;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END SP_UPDATE_SALARY;
/

DBMS_OUTPUT.PUT_LINE('✓ Created SP_UPDATE_SALARY');

-- =============================================================================
-- [SECTION 08.4] - STANDALONE PROCEDURE: APPROVE LEAVE (Medium Task)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SP_APPROVE_LEAVE(
    p_leave_id      IN NUMBER,
    p_approved_by   IN NUMBER,
    p_status        IN VARCHAR2
)
AS
    v_emp_id        NUMBER;
    v_leave_type    VARCHAR2(50);
BEGIN
    -- Validate status
    IF p_status NOT IN ('APPROVED', 'REJECTED') THEN
        RAISE_APPLICATION_ERROR(-20020, 'Status must be APPROVED or REJECTED');
    END IF;

    -- Get leave details
    SELECT emp_id, leave_type INTO v_emp_id, v_leave_type
    FROM LEAVE
    WHERE leave_id = p_leave_id;

    -- Update leave status
    UPDATE LEAVE
    SET status = p_status, approved_by = p_approved_by
    WHERE leave_id = p_leave_id;

    DBMS_OUTPUT.PUT_LINE('✓ Leave ' || p_status || ' (ID: ' || p_leave_id ||
        ', Type: ' || v_leave_type || ', Employee: ' || v_emp_id || ')');

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: Leave record not found');
        RAISE;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: ' || SQLERRM);
        ROLLBACK;
        RAISE;
END SP_APPROVE_LEAVE;
/

DBMS_OUTPUT.PUT_LINE('✓ Created SP_APPROVE_LEAVE');

-- =============================================================================
-- [SECTION 08.5] - STANDALONE FUNCTION: CALCULATE NET SALARY (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING FUNCTIONS ===');

CREATE OR REPLACE FUNCTION FN_CALCULATE_NET_SALARY(
    p_emp_id IN NUMBER
) RETURN NUMBER
AS
    v_gross_amount  NUMBER;
    v_deductions    NUMBER;
    v_net_amount    NUMBER;
    v_found         BOOLEAN := FALSE;
BEGIN
    -- Get employee salary information
    SELECT sb.amount + NVL(sb.bonus_amount, 0)
    INTO v_gross_amount
    FROM EMPLOYEE e
    JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
    WHERE e.emp_id = p_emp_id;

    v_found := TRUE;

    -- Calculate deductions (simplified: 20% tax + 10% benefits)
    v_deductions := v_gross_amount * 0.30;

    -- Calculate net
    v_net_amount := v_gross_amount - v_deductions;

    RETURN v_net_amount;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20030, 'Employee not found or not assigned salary');
        RETURN 0;
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20031, 'Error calculating net salary: ' || SQLERRM);
        RETURN 0;
END FN_CALCULATE_NET_SALARY;
/

DBMS_OUTPUT.PUT_LINE('✓ Created FN_CALCULATE_NET_SALARY');

-- =============================================================================
-- [SECTION 08.6] - FUNCTION: GET DAYS EMPLOYED (Easy Task)
-- =============================================================================

CREATE OR REPLACE FUNCTION FN_DAYS_EMPLOYED(
    p_emp_id IN NUMBER
) RETURN NUMBER
AS
    v_hire_date DATE;
    v_days      NUMBER;
BEGIN
    SELECT hire_date INTO v_hire_date
    FROM EMPLOYEE
    WHERE emp_id = p_emp_id;

    v_days := TRUNC(SYSDATE) - TRUNC(v_hire_date);

    RETURN v_days;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END FN_DAYS_EMPLOYED;
/

DBMS_OUTPUT.PUT_LINE('✓ Created FN_DAYS_EMPLOYED');

-- =============================================================================
-- [SECTION 08.7] - FUNCTION: GET DEPARTMENT HEAD COUNT (Medium Task)
-- =============================================================================

CREATE OR REPLACE FUNCTION FN_GET_DEPT_HEADCOUNT(
    p_job_id IN NUMBER
) RETURN NUMBER
AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM EMPLOYEE
    WHERE job_id = p_job_id;

    RETURN v_count;

EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;
END FN_GET_DEPT_HEADCOUNT;
/

DBMS_OUTPUT.PUT_LINE('✓ Created FN_GET_DEPT_HEADCOUNT');

-- =============================================================================
-- [SECTION 08.8] - PL/SQL PACKAGE DECLARATION (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING PL/SQL PACKAGE ===');

CREATE OR REPLACE PACKAGE PKG_EMS AS
    -- Package Name: PKG_EMS (Employee Management System)
    -- Purpose: Encapsulate core HR and payroll procedures

    -- ===== PROCEDURES =====

    PROCEDURE proc_add_employee(
        p_first_name    IN VARCHAR2,
        p_last_name     IN VARCHAR2,
        p_gender        IN CHAR,
        p_age           IN NUMBER,
        p_email         IN VARCHAR2,
        p_phone         IN VARCHAR2,
        p_job_id        IN NUMBER,
        p_salary_id     IN NUMBER,
        p_result        OUT VARCHAR2
    );

    PROCEDURE proc_add_qualification(
        p_emp_id        IN NUMBER,
        p_qual_title    IN VARCHAR2,
        p_qual_type     IN VARCHAR2,
        p_result        OUT VARCHAR2
    );

    PROCEDURE proc_process_payroll(
        p_emp_id        IN NUMBER,
        p_gross_amount  IN NUMBER,
        p_payment_date  IN DATE,
        p_result        OUT VARCHAR2
    );

    PROCEDURE proc_request_leave(
        p_emp_id        IN NUMBER,
        p_leave_type    IN VARCHAR2,
        p_start_date    IN DATE,
        p_end_date      IN DATE,
        p_reason        IN VARCHAR2,
        p_result        OUT VARCHAR2
    );

    -- ===== FUNCTIONS =====

    FUNCTION func_calculate_net_salary(p_emp_id IN NUMBER) RETURN NUMBER;

    FUNCTION func_get_employee_name(p_emp_id IN NUMBER) RETURN VARCHAR2;

    FUNCTION func_get_days_employed(p_emp_id IN NUMBER) RETURN NUMBER;

    FUNCTION func_calculate_bonus(p_salary_id IN NUMBER, p_multiplier IN NUMBER DEFAULT 1)
        RETURN NUMBER;

    -- ===== CURSOR =====

    -- Public cursor for employee data
    TYPE t_employee_rec IS RECORD (
        emp_id          EMPLOYEE.emp_id%TYPE,
        employee_name   VARCHAR2(100),
        dept_name       VARCHAR2(100),
        salary          NUMBER
    );

END PKG_EMS;
/

DBMS_OUTPUT.PUT_LINE('✓ Created PKG_EMS Package Specification');

-- =============================================================================
-- [SECTION 08.9] - PL/SQL PACKAGE BODY (Hard Task)
-- =============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_EMS AS

    --=== PROCEDURE: ADD EMPLOYEE ===
    PROCEDURE proc_add_employee(
        p_first_name    IN VARCHAR2,
        p_last_name     IN VARCHAR2,
        p_gender        IN CHAR,
        p_age           IN NUMBER,
        p_email         IN VARCHAR2,
        p_phone         IN VARCHAR2,
        p_job_id        IN NUMBER,
        p_salary_id     IN NUMBER,
        p_result        OUT VARCHAR2
    ) AS
        v_emp_id NUMBER;
    BEGIN
        INSERT INTO EMPLOYEE (first_name, last_name, gender, age, email, phone, job_id, salary_id)
        VALUES (p_first_name, p_last_name, p_gender, p_age, p_email, p_phone, p_job_id, p_salary_id)
        RETURNING emp_id INTO v_emp_id;

        p_result := 'SUCCESS: Employee ID ' || v_emp_id || ' created';
        COMMIT;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            p_result := 'ERROR: Email already in use';
            ROLLBACK;
        WHEN OTHERS THEN
            p_result := 'ERROR: ' || SQLERRM;
            ROLLBACK;
    END proc_add_employee;

    --=== PROCEDURE: ADD QUALIFICATION ===
    PROCEDURE proc_add_qualification(
        p_emp_id        IN NUMBER,
        p_qual_title    IN VARCHAR2,
        p_qual_type     IN VARCHAR2,
        p_result        OUT VARCHAR2
    ) AS
    BEGIN
        INSERT INTO QUALIFICATION (emp_id, qual_title, qual_type, grant_date)
        VALUES (p_emp_id, p_qual_title, p_qual_type, SYSDATE);

        p_result := 'SUCCESS: Qualification added';
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            p_result := 'ERROR: ' || SQLERRM;
            ROLLBACK;
    END proc_add_qualification;

    --=== PROCEDURE: PROCESS PAYROLL ===
    PROCEDURE proc_process_payroll(
        p_emp_id        IN NUMBER,
        p_gross_amount  IN NUMBER,
        p_payment_date  IN DATE,
        p_result        OUT VARCHAR2
    ) AS
        v_deductions    NUMBER;
        v_net_amount    NUMBER;
    BEGIN
        v_deductions := p_gross_amount * 0.30;
        v_net_amount := p_gross_amount - v_deductions;

        INSERT INTO PAYROLL (emp_id, payroll_date, gross_amount, deductions, net_amount, payment_status)
        VALUES (p_emp_id, p_payment_date, p_gross_amount, v_deductions, v_net_amount, 'PROCESSED');

        p_result := 'SUCCESS: Payroll processed - Net: $' || ROUND(v_net_amount, 2);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            p_result := 'ERROR: ' || SQLERRM;
            ROLLBACK;
    END proc_process_payroll;

    --=== PROCEDURE: REQUEST LEAVE ===
    PROCEDURE proc_request_leave(
        p_emp_id        IN NUMBER,
        p_leave_type    IN VARCHAR2,
        p_start_date    IN DATE,
        p_end_date      IN DATE,
        p_reason        IN VARCHAR2,
        p_result        OUT VARCHAR2
    ) AS
        v_leave_days    NUMBER;
    BEGIN
        v_leave_days := p_end_date - p_start_date + 1;

        IF v_leave_days < 0 THEN
            p_result := 'ERROR: End date must be after start date';
            RETURN;
        END IF;

        INSERT INTO LEAVE (emp_id, leave_type, leave_start, leave_end, reason, status)
        VALUES (p_emp_id, p_leave_type, p_start_date, p_end_date, p_reason, 'PENDING');

        p_result := 'SUCCESS: Leave request submitted (' || v_leave_days || ' days)';
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            p_result := 'ERROR: ' || SQLERRM;
            ROLLBACK;
    END proc_request_leave;

    --=== FUNCTION: CALCULATE NET SALARY ===
    FUNCTION func_calculate_net_salary(p_emp_id IN NUMBER) RETURN NUMBER AS
        v_salary NUMBER;
    BEGIN
        SELECT sb.amount + NVL(sb.bonus_amount, 0) * 0.70
        INTO v_salary
        FROM EMPLOYEE e
        JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
        WHERE e.emp_id = p_emp_id;

        RETURN v_salary;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END func_calculate_net_salary;

    --=== FUNCTION: GET EMPLOYEE NAME ===
    FUNCTION func_get_employee_name(p_emp_id IN NUMBER) RETURN VARCHAR2 AS
        v_name VARCHAR2(100);
    BEGIN
        SELECT first_name || ' ' || last_name
        INTO v_name
        FROM EMPLOYEE
        WHERE emp_id = p_emp_id;

        RETURN v_name;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'Unknown';
    END func_get_employee_name;

    --=== FUNCTION: GET DAYS EMPLOYED ===
    FUNCTION func_get_days_employed(p_emp_id IN NUMBER) RETURN NUMBER AS
        v_days NUMBER;
    BEGIN
        SELECT TRUNC(SYSDATE) - TRUNC(hire_date)
        INTO v_days
        FROM EMPLOYEE
        WHERE emp_id = p_emp_id;

        RETURN v_days;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END func_get_days_employed;

    --=== FUNCTION: CALCULATE BONUS ===
    FUNCTION func_calculate_bonus(p_salary_id IN NUMBER, p_multiplier IN NUMBER DEFAULT 1)
        RETURN NUMBER AS
        v_bonus NUMBER;
    BEGIN
        SELECT ROUND(bonus_amount * p_multiplier, 2)
        INTO v_bonus
        FROM SALARY_BONUS
        WHERE salary_id = p_salary_id;

        RETURN v_bonus;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END func_calculate_bonus;

END PKG_EMS;
/

DBMS_OUTPUT.PUT_LINE('✓ Created PKG_EMS Package Body');

-- =============================================================================
-- [SECTION 08.10] - TEST PACKAGE PROCEDURES (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TESTING PACKAGE PROCEDURES ===');

DECLARE
    v_result    VARCHAR2(500);
    v_net_sal   NUMBER;
    v_emp_name  VARCHAR2(100);
    v_days      NUMBER;
BEGIN
    -- Test: Add Employee
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Test 1: Adding new employee');
    PKG_EMS.proc_add_employee(
        'Robert', 'Wilson', 'M', 28, 'robert.w@ems.com', '555-0113', 1, 100, v_result
    );
    DBMS_OUTPUT.PUT_LINE(v_result);

    -- Test: Add Qualification
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Test 2: Adding qualification');
    PKG_EMS.proc_add_qualification(1000, 'Docker Certified', 'CERTIFICATION', v_result);
    DBMS_OUTPUT.PUT_LINE(v_result);

    -- Test: Request Leave
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Test 3: Requesting leave');
    PKG_EMS.proc_request_leave(
        1000, 'VACATION', TRUNC(SYSDATE + 10), TRUNC(SYSDATE + 14), 'Summer break', v_result
    );
    DBMS_OUTPUT.PUT_LINE(v_result);

    -- Test: Calculate Net Salary
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Test 4: Calculating net salary');
    v_net_sal := PKG_EMS.func_calculate_net_salary(1000);
    DBMS_OUTPUT.PUT_LINE('Net Salary for Employee 1000: $' || ROUND(v_net_sal, 2));

    -- Test: Get Employee Name
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Test 5: Getting employee name');
    v_emp_name := PKG_EMS.func_get_employee_name(1001);
    DBMS_OUTPUT.PUT_LINE('Employee 1001: ' || v_emp_name);

    -- Test: Get Days Employed
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Test 6: Getting days employed');
    v_days := PKG_EMS.func_get_days_employed(1001);
    DBMS_OUTPUT.PUT_LINE('Days Employed: ' || v_days || ' days');

END;
/

-- =============================================================================
-- [SECTION 08.11] - PACKAGE DOCUMENTATION & SUMMARY (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  PKG_EMS PACKAGE SUMMARY
═══════════════════════════════════════════════════════════════════════════

PROCEDURES IN PKG_EMS:
  1. proc_add_employee()        - Add new employee to system
  2. proc_add_qualification()   - Record employee certification/degree
  3. proc_process_payroll()     - Process monthly payroll
  4. proc_request_leave()       - Submit leave request

FUNCTIONS IN PKG_EMS:
  1. func_calculate_net_salary()    - Calculate employee net pay
  2. func_get_employee_name()       - Retrieve formatted employee name
  3. func_get_days_employed()       - Calculate tenure in days
  4. func_calculate_bonus()         - Calculate bonus with multiplier

BENEFITS OF PACKAGE-BASED ARCHITECTURE:
  ✓ Code reusability - Procedures/functions in one namespace
  ✓ Better security - Can grant EXECUTE privilege on package
  ✓ Reduced network traffic - Call once, execute many operations
  ✓ Version control - Easy to maintain package versions
  ✓ Logical organization - Related functionality grouped together

USAGE EXAMPLES:

  -- Call procedure
  DECLARE
    v_result VARCHAR2(500);
  BEGIN
    PKG_EMS.proc_add_employee(..., v_result);
    DBMS_OUTPUT.PUT_LINE(v_result);
  END;
  /

  -- Call function
  DECLARE
    v_net_sal NUMBER;
  BEGIN
    v_net_sal := PKG_EMS.func_calculate_net_salary(1000);
  END;
  /

═══════════════════════════════════════════════════════════════════════════
  PROCEDURES, FUNCTIONS & PACKAGES COMPLETE
═══════════════════════════════════════════════════════════════════════════
');

COMMIT;

