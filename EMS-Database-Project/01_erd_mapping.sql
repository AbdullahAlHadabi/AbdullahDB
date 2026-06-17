-- =============================================================================
-- 01_erd_mapping.sql
-- EMPLOYEE MANAGEMENT SYSTEM (EMS) - ERD MAPPING & DDL
-- ORACLE 19c / PL-SQL
-- =============================================================================
-- OBJECTIVE:
--   - Define the Relational Schema with full Entity-Relationship mapping
--   - Create 6 base tables with proper Primary Keys, Foreign Keys, and Constraints
--   - Create 6 Sequences for auto-incrementing PKs
--   - Implement CHECK constraints for data integrity
-- =============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

-- =============================================================================
-- [SECTION 01.0] - CLEANUP (Idempotent)
-- Drop existing objects to allow re-running script without ORA-00955 errors
-- =============================================================================
BEGIN
    -- Drop tables in reverse dependency order
    FOR r IN (SELECT table_name FROM user_tables
              WHERE table_name IN (
                  'PAYROLL', 'LEAVE', 'QUALIFICATION',
                  'EMPLOYEE', 'SALARY_BONUS', 'JOB_DEPARTMENT'
              ))
    LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || r.table_name || ' CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('Dropped table: ' || r.table_name);
    END LOOP;

    -- Drop sequences
    FOR s IN (SELECT sequence_name FROM user_sequences
              WHERE sequence_name IN (
                  'SEQ_JOB_DEPARTMENT', 'SEQ_SALARY_BONUS',
                  'SEQ_EMPLOYEE', 'SEQ_QUALIFICATION',
                  'SEQ_LEAVE', 'SEQ_PAYROLL'
              ))
    LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
        DBMS_OUTPUT.PUT_LINE('Dropped sequence: ' || s.sequence_name);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Cleanup complete.');

EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -4043 AND SQLCODE != -2289 THEN
            RAISE;
        END IF;
END;
/

-- =============================================================================
-- [SECTION 01.1] - RELATIONAL SCHEMA MAPPING
-- =============================================================================
-- ENTITIES & RELATIONSHIPS:
--
-- JOB_DEPARTMENT (job_id PK)
--   ├─ EMPLOYEE (emp_id PK, job_id FK, salary_id FK)
--   ├─ SALARY_BONUS (salary_id PK, job_id FK)
--   ├─ LEAVE (leave_id PK, emp_id FK)
--   ├─ QUALIFICATION (qual_id PK, emp_id FK)
--   └─ PAYROLL (payroll_id PK, emp_id FK, job_id FK, salary_id FK, leave_id FK)
--
-- NORMALIZATION: All tables are in 3NF (see 02_normalization.sql)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING SEQUENCES ===');

-- =============================================================================
-- [SECTION 01.2] - CREATE SEQUENCES (Easy Task)
-- Provides auto-incrementing Primary Key values for all tables
-- =============================================================================

CREATE SEQUENCE SEQ_JOB_DEPARTMENT
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;
DBMS_OUTPUT.PUT_LINE('✓ Sequence SEQ_JOB_DEPARTMENT created');

CREATE SEQUENCE SEQ_SALARY_BONUS
    START WITH 100
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;
DBMS_OUTPUT.PUT_LINE('✓ Sequence SEQ_SALARY_BONUS created');

CREATE SEQUENCE SEQ_EMPLOYEE
    START WITH 1000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;
DBMS_OUTPUT.PUT_LINE('✓ Sequence SEQ_EMPLOYEE created');

CREATE SEQUENCE SEQ_QUALIFICATION
    START WITH 5000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;
DBMS_OUTPUT.PUT_LINE('✓ Sequence SEQ_QUALIFICATION created');

CREATE SEQUENCE SEQ_LEAVE
    START WITH 3000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;
DBMS_OUTPUT.PUT_LINE('✓ Sequence SEQ_LEAVE created');

CREATE SEQUENCE SEQ_PAYROLL
    START WITH 2000
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;
DBMS_OUTPUT.PUT_LINE('✓ Sequence SEQ_PAYROLL created');

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING TABLES ===');

-- =============================================================================
-- [SECTION 01.3] - CREATE BASE TABLES
-- =============================================================================

-- TABLE 1: JOB_DEPARTMENT
-- Stores organizational departments and job roles
CREATE TABLE JOB_DEPARTMENT (
    job_id          NUMBER          PRIMARY KEY DEFAULT SEQ_JOB_DEPARTMENT.NEXTVAL,
    dept_name       VARCHAR2(100)   NOT NULL,
    dept_description VARCHAR2(500),
    salary_range    VARCHAR2(50),
    created_date    DATE            DEFAULT SYSDATE
);

DBMS_OUTPUT.PUT_LINE('✓ Table JOB_DEPARTMENT created');

-- TABLE 2: SALARY_BONUS
-- Stores salary and bonus information per job department
CREATE TABLE SALARY_BONUS (
    salary_id       NUMBER          PRIMARY KEY DEFAULT SEQ_SALARY_BONUS.NEXTVAL,
    amount          NUMBER(10, 2)   NOT NULL,
    bonus_amount    NUMBER(10, 2)   DEFAULT 0,
    annual_increase NUMBER(5, 2)    DEFAULT 5,
    job_id          NUMBER          NOT NULL,
    created_date    DATE            DEFAULT SYSDATE,

    -- Constraints
    CONSTRAINT chk_salary_positive CHECK (amount > 0),
    CONSTRAINT chk_bonus_non_negative CHECK (bonus_amount >= 0),
    CONSTRAINT fk_salary_job FOREIGN KEY (job_id)
        REFERENCES JOB_DEPARTMENT(job_id) ON DELETE CASCADE
);

DBMS_OUTPUT.PUT_LINE('✓ Table SALARY_BONUS created');

-- TABLE 3: EMPLOYEE
-- Core employee information with gender and contact details
CREATE TABLE EMPLOYEE (
    emp_id          NUMBER          PRIMARY KEY DEFAULT SEQ_EMPLOYEE.NEXTVAL,
    first_name      VARCHAR2(50)    NOT NULL,
    last_name       VARCHAR2(50)    NOT NULL,
    gender          CHAR(1),
    age             NUMBER(3),
    email           VARCHAR2(100)   UNIQUE,
    phone           VARCHAR2(15),
    hire_date       DATE            DEFAULT SYSDATE,
    job_id          NUMBER,
    salary_id       NUMBER,

    -- Constraints
    CONSTRAINT chk_gender CHECK (gender IN ('M', 'F')),
    CONSTRAINT chk_age CHECK (age >= 18 AND age <= 75),
    CONSTRAINT fk_emp_job FOREIGN KEY (job_id)
        REFERENCES JOB_DEPARTMENT(job_id) ON DELETE SET NULL,
    CONSTRAINT fk_emp_salary FOREIGN KEY (salary_id)
        REFERENCES SALARY_BONUS(salary_id) ON DELETE SET NULL
);

DBMS_OUTPUT.PUT_LINE('✓ Table EMPLOYEE created');

-- TABLE 4: QUALIFICATION
-- Stores employee certifications and qualifications
CREATE TABLE QUALIFICATION (
    qual_id         NUMBER          PRIMARY KEY DEFAULT SEQ_QUALIFICATION.NEXTVAL,
    qual_title      VARCHAR2(150)   NOT NULL,
    qual_type       VARCHAR2(50)    DEFAULT 'CERTIFICATION',
    grant_date      DATE,
    emp_id          NUMBER          NOT NULL,

    -- Constraints
    CONSTRAINT fk_qual_emp FOREIGN KEY (emp_id)
        REFERENCES EMPLOYEE(emp_id) ON DELETE CASCADE
);

DBMS_OUTPUT.PUT_LINE('✓ Table QUALIFICATION created');

-- TABLE 5: LEAVE
-- Tracks employee leave requests and approvals
CREATE TABLE LEAVE (
    leave_id        NUMBER          PRIMARY KEY DEFAULT SEQ_LEAVE.NEXTVAL,
    leave_type      VARCHAR2(50)    DEFAULT 'SICK',
    leave_start     DATE            NOT NULL,
    leave_end       DATE,
    reason          VARCHAR2(255),
    status          VARCHAR2(20)    DEFAULT 'PENDING',
    emp_id          NUMBER          NOT NULL,
    approved_by     NUMBER,

    -- Constraints
    CONSTRAINT chk_leave_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    CONSTRAINT chk_leave_dates CHECK (leave_end >= leave_start OR leave_end IS NULL),
    CONSTRAINT fk_leave_emp FOREIGN KEY (emp_id)
        REFERENCES EMPLOYEE(emp_id) ON DELETE CASCADE
);

DBMS_OUTPUT.PUT_LINE('✓ Table LEAVE created');

-- TABLE 6: PAYROLL
-- Tracks payroll entries, deductions, and net pay
CREATE TABLE PAYROLL (
    payroll_id      NUMBER          PRIMARY KEY DEFAULT SEQ_PAYROLL.NEXTVAL,
    payroll_date    DATE            NOT NULL DEFAULT SYSDATE,
    gross_amount    NUMBER(10, 2)   NOT NULL,
    deductions      NUMBER(10, 2)   DEFAULT 0,
    net_amount      NUMBER(10, 2),
    emp_id          NUMBER          NOT NULL,
    job_id          NUMBER,
    salary_id       NUMBER,
    leave_id        NUMBER,
    payment_status  VARCHAR2(20)    DEFAULT 'PENDING',

    -- Constraints
    CONSTRAINT chk_payroll_gross CHECK (gross_amount > 0),
    CONSTRAINT chk_payroll_deductions CHECK (deductions >= 0),
    CONSTRAINT chk_payroll_status CHECK (payment_status IN ('PENDING', 'PROCESSED', 'PAID')),
    CONSTRAINT fk_payroll_emp FOREIGN KEY (emp_id)
        REFERENCES EMPLOYEE(emp_id) ON DELETE CASCADE,
    CONSTRAINT fk_payroll_job FOREIGN KEY (job_id)
        REFERENCES JOB_DEPARTMENT(job_id) ON DELETE SET NULL,
    CONSTRAINT fk_payroll_salary FOREIGN KEY (salary_id)
        REFERENCES SALARY_BONUS(salary_id) ON DELETE SET NULL,
    CONSTRAINT fk_payroll_leave FOREIGN KEY (leave_id)
        REFERENCES LEAVE(leave_id) ON DELETE SET NULL
);

DBMS_OUTPUT.PUT_LINE('✓ Table PAYROLL created');

-- =============================================================================
-- [SECTION 01.4] - CREATE INDEXES (Medium Task)
-- Improves query performance on frequently searched columns
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING INDEXES ===');

CREATE INDEX idx_emp_email ON EMPLOYEE(email);
DBMS_OUTPUT.PUT_LINE('✓ Index idx_emp_email created');

CREATE INDEX idx_emp_job ON EMPLOYEE(job_id);
DBMS_OUTPUT.PUT_LINE('✓ Index idx_emp_job created');

CREATE INDEX idx_payroll_emp ON PAYROLL(emp_id);
DBMS_OUTPUT.PUT_LINE('✓ Index idx_payroll_emp created');

CREATE INDEX idx_payroll_date ON PAYROLL(payroll_date);
DBMS_OUTPUT.PUT_LINE('✓ Index idx_payroll_date created');

CREATE INDEX idx_leave_emp ON LEAVE(emp_id);
DBMS_OUTPUT.PUT_LINE('✓ Index idx_leave_emp created');

-- =============================================================================
-- [SECTION 01.5] - VERIFY SCHEMA (Hard Task)
-- Query data dictionary to confirm all objects created successfully
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== SCHEMA VERIFICATION ===');

DECLARE
    v_table_count   NUMBER;
    v_seq_count     NUMBER;
    v_index_count   NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_count
    FROM user_tables
    WHERE table_name IN ('JOB_DEPARTMENT', 'SALARY_BONUS', 'EMPLOYEE',
                        'QUALIFICATION', 'LEAVE', 'PAYROLL');

    SELECT COUNT(*) INTO v_seq_count
    FROM user_sequences
    WHERE sequence_name LIKE 'SEQ_%';

    SELECT COUNT(*) INTO v_index_count
    FROM user_indexes
    WHERE index_name LIKE 'IDX_%';

    DBMS_OUTPUT.PUT_LINE('Tables created: ' || v_table_count || '/6');
    DBMS_OUTPUT.PUT_LINE('Sequences created: ' || v_seq_count || '/6');
    DBMS_OUTPUT.PUT_LINE('Indexes created: ' || v_index_count || '/5');

    IF v_table_count = 6 AND v_seq_count = 6 THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '✓✓✓ ERD MAPPING & DDL COMPLETE ✓✓✓');
    END IF;
END;
/

COMMIT;

