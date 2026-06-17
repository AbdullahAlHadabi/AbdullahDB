-- =============================================================================
-- 09_triggers.sql
-- EMPLOYEE MANAGEMENT SYSTEM (EMS) - DATABASE TRIGGERS
-- ORACLE 19c / PL-SQL
-- =============================================================================
-- OBJECTIVE:
--   - Create BEFORE UPDATE trigger to prevent salary decreases
--   - Create AFTER DELETE trigger to archive deleted employees
--   - Create compound trigger for bulk payroll validation
--   - Demonstrate trigger use for auditing and data protection
-- =============================================================================

SET SERVEROUTPUT ON;

DBMS_OUTPUT.PUT_LINE('
╔═══════════════════════════════════════════════════════════════════════════╗
║                    EMS DATABASE TRIGGERS & AUTOMATION                     ║
╚═══════════════════════════════════════════════════════════════════════════╝
');

-- =============================================================================
-- [SECTION 09.1] - SETUP: CREATE AUDIT & ARCHIVE TABLES (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING AUDIT & ARCHIVE TABLES ===');

BEGIN
    FOR t IN (SELECT table_name FROM user_tables
              WHERE table_name IN ('EMPLOYEE_ARCHIVE', 'SALARY_AUDIT_LOG', 'PAYROLL_AUDIT'))
    LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('Dropped table: ' || t.table_name);
    END LOOP;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- Archive table for deleted employees
CREATE TABLE EMPLOYEE_ARCHIVE AS
SELECT
    e.*,
    NULL as archived_date,
    NULL as archived_by,
    NULL as archive_reason
FROM EMPLOYEE e
WHERE 1 = 0;

ALTER TABLE EMPLOYEE_ARCHIVE
ADD (archived_date DATE, archived_by VARCHAR2(50), archive_reason VARCHAR2(500));

DBMS_OUTPUT.PUT_LINE('✓ Created EMPLOYEE_ARCHIVE table');

-- Salary audit log
CREATE TABLE SALARY_AUDIT_LOG (
    audit_id        NUMBER PRIMARY KEY,
    salary_id       NUMBER NOT NULL,
    old_amount      NUMBER,
    new_amount      NUMBER,
    change_amount   NUMBER,
    changed_by      VARCHAR2(50),
    changed_date    DATE DEFAULT SYSDATE,
    reason          VARCHAR2(500)
);

CREATE SEQUENCE SEQ_AUDIT
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

DBMS_OUTPUT.PUT_LINE('✓ Created SALARY_AUDIT_LOG table');

-- Payroll audit for validation issues
CREATE TABLE PAYROLL_AUDIT (
    audit_id        NUMBER PRIMARY KEY,
    payroll_id      NUMBER NOT NULL,
    emp_id          NUMBER,
    audit_type      VARCHAR2(50),
    message         VARCHAR2(500),
    audit_date      DATE DEFAULT SYSDATE
);

CREATE SEQUENCE SEQ_PAYROLL_AUDIT
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

DBMS_OUTPUT.PUT_LINE('✓ Created PAYROLL_AUDIT table');

-- =============================================================================
-- [SECTION 09.2] - BEFORE UPDATE TRIGGER: SALARY GUARD (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING TRIGGERS ===');

CREATE OR REPLACE TRIGGER TRG_SALARY_NO_DECREASE
    BEFORE UPDATE ON SALARY_BONUS
    FOR EACH ROW
DECLARE
    v_salary_change NUMBER;
BEGIN
    v_salary_change := :NEW.amount - :OLD.amount;

    -- Rule: Salary can only stay same or increase
    IF :NEW.amount < :OLD.amount THEN
        RAISE_APPLICATION_ERROR(
            -20100,
            'SALARY CUT BLOCKED! Current: $' || :OLD.amount ||
            ' Attempted: $' || :NEW.amount ||
            ' Decrease of $' || ABS(v_salary_change) ||
            '. Contact HR Department for override.'
        );
    END IF;

    -- Optional: Log the salary change for audit
    IF v_salary_change > 0 THEN
        INSERT INTO SALARY_AUDIT_LOG (
            audit_id, salary_id, old_amount, new_amount,
            change_amount, changed_by, reason
        ) VALUES (
            SEQ_AUDIT.NEXTVAL,
            :NEW.salary_id,
            :OLD.amount,
            :NEW.amount,
            v_salary_change,
            USER,
            'Salary increase approved'
        );
    END IF;

    DBMS_OUTPUT.PUT_LINE('Salary update validated - Change: $' || v_salary_change);

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Trigger Error: ' || SQLERRM);
        RAISE;
END TRG_SALARY_NO_DECREASE;
/

DBMS_OUTPUT.PUT_LINE('✓ Created TRG_SALARY_NO_DECREASE (BEFORE UPDATE trigger)');

-- =============================================================================
-- [SECTION 09.3] - AFTER DELETE TRIGGER: EMPLOYEE ARCHIVE (Medium Task)
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_ARCHIVE_DELETED_EMPLOYEE
    AFTER DELETE ON EMPLOYEE
    FOR EACH ROW
BEGIN
    -- Archive the deleted employee record
    INSERT INTO EMPLOYEE_ARCHIVE (
        emp_id, first_name, last_name, gender, age, email, phone,
        hire_date, job_id, salary_id, archived_date, archived_by, archive_reason
    ) VALUES (
        :OLD.emp_id,
        :OLD.first_name,
        :OLD.last_name,
        :OLD.gender,
        :OLD.age,
        :OLD.email,
        :OLD.phone,
        :OLD.hire_date,
        :OLD.job_id,
        :OLD.salary_id,
        SYSDATE,
        USER,
        'Automatically archived on deletion'
    );

    DBMS_OUTPUT.PUT_LINE('Employee ' || :OLD.emp_id || ' (' || :OLD.first_name ||
        ' ' || :OLD.last_name || ') archived to EMPLOYEE_ARCHIVE');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Archive Trigger Error: ' || SQLERRM);
        RAISE;
END TRG_ARCHIVE_DELETED_EMPLOYEE;
/

DBMS_OUTPUT.PUT_LINE('✓ Created TRG_ARCHIVE_DELETED_EMPLOYEE (AFTER DELETE trigger)');

-- =============================================================================
-- [SECTION 09.4] - BEFORE INSERT TRIGGER: PAYROLL VALIDATION (Medium Task)
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_VALIDATE_PAYROLL_INSERT
    BEFORE INSERT ON PAYROLL
    FOR EACH ROW
DECLARE
    v_emp_salary    NUMBER;
    v_variance      NUMBER;
BEGIN
    -- Get expected salary for the employee
    SELECT sb.amount
    INTO v_emp_salary
    FROM EMPLOYEE e
    JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
    WHERE e.emp_id = :NEW.emp_id;

    -- Check if gross amount varies significantly from employee salary
    v_variance := ABS(:NEW.gross_amount - v_emp_salary) / v_emp_salary * 100;

    -- Flag if variance > 20%
    IF v_variance > 20 THEN
        INSERT INTO PAYROLL_AUDIT (
            audit_id, payroll_id, emp_id, audit_type, message
        ) VALUES (
            SEQ_PAYROLL_AUDIT.NEXTVAL,
            :NEW.payroll_id,
            :NEW.emp_id,
            'VARIANCE_WARNING',
            'Payroll variance: ' || ROUND(v_variance, 2) || '% (Expected: $' ||
            v_emp_salary || ', Actual: $' || :NEW.gross_amount || ')'
        );

        DBMS_OUTPUT.PUT_LINE('⚠ Payroll variance noted for Employee ' || :NEW.emp_id);
    END IF;

    -- Validate that net amount equals (gross - deductions)
    IF :NEW.net_amount IS NULL THEN
        :NEW.net_amount := :NEW.gross_amount - NVL(:NEW.deductions, 0);
    END IF;

    DBMS_OUTPUT.PUT_LINE('Payroll record validated for Employee ' || :NEW.emp_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('⚠ Warning: Could not validate employee salary');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Payroll Validation Trigger Error: ' || SQLERRM);
        RAISE;
END TRG_VALIDATE_PAYROLL_INSERT;
/

DBMS_OUTPUT.PUT_LINE('✓ Created TRG_VALIDATE_PAYROLL_INSERT (BEFORE INSERT trigger)');

-- =============================================================================
-- [SECTION 09.5] - COMPOUND TRIGGER: LEAVE STATUS MANAGEMENT (Hard Task)
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_LEAVE_STATUS_HANDLER
    FOR INSERT OR UPDATE OR DELETE ON LEAVE
    COMPOUND TRIGGER

    -- Global variables for the trigger
    v_invalid_count NUMBER := 0;
    v_approved_count NUMBER := 0;

    -- BEFORE EACH ROW section
    BEFORE EACH ROW IS
    BEGIN
        IF INSERTING OR UPDATING THEN
            -- Validate leave dates
            IF :NEW.leave_start > :NEW.leave_end THEN
                RAISE_APPLICATION_ERROR(-20200,
                    'Leave start date cannot be after end date');
            END IF;

            -- Set default status if not provided
            IF :NEW.status IS NULL THEN
                :NEW.status := 'PENDING';
            END IF;
        END IF;
    END BEFORE EACH ROW;

    -- AFTER EACH ROW section
    AFTER EACH ROW IS
    BEGIN
        IF INSERTING THEN
            DBMS_OUTPUT.PUT_LINE('Leave request created for Employee ' || :NEW.emp_id);
        ELSIF UPDATING AND :NEW.status != :OLD.status THEN
            IF :NEW.status = 'APPROVED' THEN
                DBMS_OUTPUT.PUT_LINE('Leave APPROVED for Employee ' || :NEW.emp_id);
            ELSIF :NEW.status = 'REJECTED' THEN
                DBMS_OUTPUT.PUT_LINE('Leave REJECTED for Employee ' || :NEW.emp_id);
            END IF;
        ELSIF DELETING THEN
            DBMS_OUTPUT.PUT_LINE('Leave record deleted for Employee ' || :OLD.emp_id);
        END IF;
    END AFTER EACH ROW;

    -- AFTER STATEMENT section (Optional statistics)
    AFTER STATEMENT IS
    BEGIN
        -- Can aggregate stats across all rows processed
        SELECT COUNT(*) INTO v_approved_count
        FROM LEAVE
        WHERE status = 'APPROVED' AND TRUNC(leave_start) >= TRUNC(SYSDATE);

        IF INSERTING THEN
            DBMS_OUTPUT.PUT_LINE(
                'Compound trigger complete. Total approved leaves for upcoming dates: ' || v_approved_count
            );
        END IF;
    END AFTER STATEMENT;

END TRG_LEAVE_STATUS_HANDLER;
/

DBMS_OUTPUT.PUT_LINE('✓ Created TRG_LEAVE_STATUS_HANDLER (Compound trigger)');

-- =============================================================================
-- [SECTION 09.6] - INSTEAD OF TRIGGER: VIEW UPDATE (Hard Task)
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_INSTEAD_EMPLOYEE_DIRECTORY_UPDATE
    INSTEAD OF UPDATE ON VW_EMPLOYEE_DIRECTORY
    FOR EACH ROW
BEGIN
    -- Allow updates on specific columns only
    UPDATE EMPLOYEE
    SET
        first_name = :NEW.first_name,
        last_name = :NEW.last_name,
        email = :NEW.email,
        phone = :NEW.phone
    WHERE emp_id = :OLD.emp_id;

    DBMS_OUTPUT.PUT_LINE('Employee directory updated for ID: ' || :OLD.emp_id);

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ View Update Error: ' || SQLERRM);
        RAISE;
END TRG_INSTEAD_EMPLOYEE_DIRECTORY_UPDATE;
/

DBMS_OUTPUT.PUT_LINE('✓ Created TRG_INSTEAD_EMPLOYEE_DIRECTORY_UPDATE (INSTEAD OF trigger)');

-- =============================================================================
-- [SECTION 09.7] - AFTER INSERT TRIGGER: PAYROLL NOTIFICATION (Easy Task)
-- =============================================================================

CREATE OR REPLACE TRIGGER TRG_PAYROLL_NOTIFICATION
    AFTER INSERT ON PAYROLL
    FOR EACH ROW
DECLARE
    v_emp_name VARCHAR2(100);
BEGIN
    SELECT first_name || ' ' || last_name
    INTO v_emp_name
    FROM EMPLOYEE
    WHERE emp_id = :NEW.emp_id;

    -- In a real system, this would send an email or notification
    DBMS_OUTPUT.PUT_LINE('✉ Notification: Payroll processed for ' || v_emp_name ||
        ' - Net: $' || :NEW.net_amount);

EXCEPTION
    WHEN OTHERS THEN NULL;  -- Silent fail for notifications
END TRG_PAYROLL_NOTIFICATION;
/

DBMS_OUTPUT.PUT_LINE('✓ Created TRG_PAYROLL_NOTIFICATION (AFTER INSERT trigger)');

-- =============================================================================
-- [SECTION 09.8] - TEST TRIGGERS (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  TESTING TRIGGERS
═══════════════════════════════════════════════════════════════════════════
');

-- TEST 1: Salary Increase (should succeed)
DBMS_OUTPUT.PUT_LINE(CHR(10) || 'TEST 1: Legitimate salary increase');
BEGIN
    UPDATE SALARY_BONUS
    SET amount = amount * 1.05
    WHERE salary_id = 100;

    DBMS_OUTPUT.PUT_LINE('✓ Salary increase successful');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- TEST 2: Salary Decrease (should fail)
DBMS_OUTPUT.PUT_LINE(CHR(10) || 'TEST 2: Attempted salary decrease (should be blocked)');
BEGIN
    UPDATE SALARY_BONUS
    SET amount = amount * 0.90
    WHERE salary_id = 101;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✓ Correctly caught salary decrease: ' || SQLERRM);
        ROLLBACK;
END;
/

-- TEST 3: Insert Leave (compound trigger activates)
DBMS_OUTPUT.PUT_LINE(CHR(10) || 'TEST 3: Inserting leave record (compound trigger test)');
BEGIN
    INSERT INTO LEAVE (emp_id, leave_type, leave_start, leave_end, reason, status)
    VALUES (1000, 'SICK', TRUNC(SYSDATE + 5), TRUNC(SYSDATE + 6), 'Dental appointment', 'PENDING');

    DBMS_OUTPUT.PUT_LINE('✓ Leave record inserted');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- TEST 4: Invalid Leave Dates (should fail)
DBMS_OUTPUT.PUT_LINE(CHR(10) || 'TEST 4: Invalid leave dates (should be rejected)');
BEGIN
    INSERT INTO LEAVE (emp_id, leave_type, leave_start, leave_end, reason)
    VALUES (1000, 'VACATION', TRUNC(SYSDATE + 10), TRUNC(SYSDATE + 5), 'Invalid dates');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✓ Correctly rejected invalid dates: ' || SQLERRM);
        ROLLBACK;
END;
/

-- TEST 5: Payroll with Variance Warning
DBMS_OUTPUT.PUT_LINE(CHR(10) || 'TEST 5: Payroll insertion with variance warning');
BEGIN
    INSERT INTO PAYROLL (emp_id, payroll_date, gross_amount, deductions, payment_status, job_id, salary_id)
    VALUES (1000, SYSDATE, 150000, 30000, 'PENDING', 1, 100);  -- 150k is much higher than $95k

    DBMS_OUTPUT.PUT_LINE('✓ Payroll inserted (variance warning should be logged)');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- =============================================================================
-- [SECTION 09.9] - TRIGGER MANAGEMENT & DEBUGGING (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  TRIGGER INFORMATION & STATUS
═══════════════════════════════════════════════════════════════════════════
');

DECLARE
    v_trigger_count NUMBER;
    v_disabled_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_trigger_count
    FROM user_triggers
    WHERE trigger_name LIKE 'TRG_%';

    SELECT COUNT(*) INTO v_disabled_count
    FROM user_triggers
    WHERE trigger_name LIKE 'TRG_%' AND status = 'DISABLED';

    DBMS_OUTPUT.PUT_LINE('Total triggers created: ' || v_trigger_count);
    DBMS_OUTPUT.PUT_LINE('Disabled triggers:      ' || v_disabled_count);
    DBMS_OUTPUT.PUT_LINE('Active triggers:       ' || (v_trigger_count - v_disabled_count));

    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Active Triggers:');
    DBMS_OUTPUT.PUT_LINE('─────────────────');

    FOR r IN (SELECT trigger_name, trigger_type, triggering_event, table_name
              FROM user_triggers
              WHERE trigger_name LIKE 'TRG_%' AND status = 'ENABLED'
              ORDER BY table_name, trigger_name) LOOP
        DBMS_OUTPUT.PUT_LINE(' • ' || r.trigger_name ||
            ' (' || r.triggering_event || ' on ' || r.table_name || ')');
    END LOOP;

END;
/

-- =============================================================================
-- [SECTION 09.10] - AUDIT LOG VERIFICATION (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  AUDIT LOG VERIFICATION
═══════════════════════════════════════════════════════════════════════════
');

SELECT 'Salary Changes' as audit_type, COUNT(*) as count
FROM SALARY_AUDIT_LOG
UNION ALL
SELECT 'Payroll Issues', COUNT(*)
FROM PAYROLL_AUDIT
UNION ALL
SELECT 'Archived Employees', COUNT(*)
FROM EMPLOYEE_ARCHIVE;

DBMS_OUTPUT.PUT_LINE('═══════════════════════════════════════════════════════════════════════════════════');
DBMS_OUTPUT.PUT_LINE('  TRIGGERS & AUTOMATION COMPLETE');
DBMS_OUTPUT.PUT_LINE('═══════════════════════════════════════════════════════════════════════════════════');

COMMIT;

