# EMS (Employee Management System) - Complete Database Project
-- =============================================================================

**Project Date:** June 2026  
**Technology Stack:** Oracle Database 19c, PL/SQL, DBMS_SCHEDULER, SQL/DML  

---
---

## Executive Summary

The **Employee Management System (EMS)** is a comprehensive, production-ready Oracle Database solution designed to manage employee information, payroll, leave, qualifications, and organizational hierarchy. This project demonstrates advanced PL/SQL capabilities including:

- **Normalized Relational Schema** (3NF) with 6 core tables and optimized indexing
- **Sophisticated DML Operations** including transaction control with SAVEPOINT
- **Advanced SQL Features** including GROUP BY ROLLUP, window functions, CTEs, and complex joins
- **Server-Side Logic** via stored procedures, functions, and packages
- **Data Protection** through triggers (BEFORE UPDATE, AFTER DELETE, compound triggers)
- **Automated Workflows** using DBMS_SCHEDULER with multi-step chains
- **View-Based Security** with role-based data access patterns

### Key Metrics
| Metric | Value |
|--------|-------|
| Core Tables | 6 entities |
| Archive Tables | 3 (EMPLOYEE_ARCHIVE, SALARY_AUDIT_LOG, PAYROLL_AUDIT) |
| Sequences | 7 (for PK auto-increment) |
| Primary Keys | 6 |
| Foreign Keys | 11 |
| Check Constraints | 8 |
| Views (Simple) | 6 |
| Materialized Views | 3 |
| Stored Procedures | 10+ |
| Functions | 4+ |
| Triggers | 6 |
| Scheduled Jobs | 3 |
| Scheduler Chains | 1 (5-step pipeline) |

---

## Project Architecture

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│           APPLICATION LAYER                                 │
│  (Business Applications, Reports, Employee Portal)          │
└──────────────────────────┬──────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    ┌─────────┐      ┌──────────┐      ┌──────────┐
    │  VIEWS  │      │ PACKAGES │      │ FUNCTIONS│
    │ (6+3)   │      │ (PKG_EMS)│      │ (FN_*)   │
    └────┬────┘      └────┬─────┘      └────┬─────┘
         │                │                  │
         └────────────────┼──────────────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
    ┌─────────────┐  ┌───────────────┐ ┌──────────────┐
    │  TRIGGERS   │  │  CORE TABLES  │ │  SEQUENCES   │
    │ (6 active)  │  │   (6 tables)  │ │   (7 seqs)   │
    └─────────────┘  └───────────────┘ └──────────────┘
         │                │                │
         │        ┌───────┼────────┐       │
         │        ▼       ▼        ▼       ▼
         └────> JOB_DEPARTMENT, EMPLOYEE, SALARY_BONUS,
                QUALIFICATION, LEAVE, PAYROLL

         ┌─────────────────────────────┐
         │  DBMS_SCHEDULER             │
         │  Automated Jobs & Chains    │
         │  (3 jobs + 5-step pipeline) │
         └─────────────────────────────┘
```

### Database Relationships

```
JOB_DEPARTMENT (job_id PK)
    ├─ EMPLOYEE (emp_id PK, job_id FK, salary_id FK)
    │   ├─ LEAVE (leave_id PK, emp_id FK) [status: PENDING/APPROVED/REJECTED]
    │   ├─ QUALIFICATION (qual_id PK, emp_id FK) [training records]
    │   └─ PAYROLL (payroll_id PK, emp_id FK, job_id FK)
    │
    └─ SALARY_BONUS (salary_id PK, job_id FK)
        └─ PAYROLL (references salary_id)
```

---

## Database Schema Design

### 1. JOB_DEPARTMENT Table
**Purpose:** Stores job titles, departments, and salary ranges
```sql
PK: job_id (auto-generated via SEQ_JOB_DEPARTMENT)
Attributes:
  • dept_name VARCHAR2(100) NOT NULL
  • dept_description VARCHAR2(500)
  • salary_range VARCHAR2(50)
  • created_date DATE DEFAULT SYSDATE

Constraints:
  • PRIMARY KEY (job_id)
```

**Business Logic:**
- Acts as master reference for all organizational units
- One-to-many relationship with EMPLOYEE and SALARY_BONUS
- Supports hierarchical department querying

### 2. EMPLOYEE Table
**Purpose:** Stores employee master data
```sql
PK: emp_id (auto-generated via SEQ_EMPLOYEE starting at 1000)
FK: job_id → JOB_DEPARTMENT.job_id
FK: salary_id → SALARY_BONUS.salary_id

Attributes:
  • first_name VARCHAR2(50) NOT NULL
  • last_name VARCHAR2(50) NOT NULL
  • gender CHAR(1) CHECK (gender IN ('M', 'F'))
  • age NUMBER(3) CHECK (age >= 18 AND age <= 75)
  • email VARCHAR2(100) UNIQUE
  • phone VARCHAR2(15)
  • hire_date DATE DEFAULT SYSDATE
  • job_id NUMBER
  • salary_id NUMBER

Constraints:
  • PRIMARY KEY (emp_id)
  • UNIQUE (email) - Email uniqueness enforced
  • CHECK (gender IN ('M', 'F'))
  • CHECK (age >= 18 AND age <= 75)
```

**Key Features:**
- Email uniqueness enforced at database level
- Gender validation at constraint level
- Age validation prevents data entry errors
- Cascading delete from JOB_DEPARTMENT sets job_id to NULL
- Cascading delete from SALARY_BONUS sets salary_id to NULL

### 3. SALARY_BONUS Table
**Purpose:** Stores compensation information per job
```sql
PK: salary_id (auto-generated via SEQ_SALARY_BONUS starting at 100)
FK: job_id → JOB_DEPARTMENT.job_id

Attributes:
  • amount NUMBER(10,2) NOT NULL CHECK (amount > 0)
  • bonus_amount NUMBER(10,2) DEFAULT 0 CHECK (bonus_amount >= 0)
  • annual_increase NUMBER(5,2) DEFAULT 5
  • job_id NUMBER NOT NULL
  • created_date DATE DEFAULT SYSDATE
```

**Key Features:**
- Amount validation: Must be positive (CHECK amount > 0)
- Bonus validation: Must be non-negative
- Supports multiple salary levels per job
- BEFORE UPDATE trigger prevents salary decreases (TRG_SALARY_NO_DECREASE)
- Audit trail maintained via SALARY_AUDIT_LOG

### 4. LEAVE Table
**Purpose:** Tracks employee leave requests
```sql
PK: leave_id (auto-generated via SEQ_LEAVE starting at 3000)
FK: emp_id → EMPLOYEE.emp_id
FK: approved_by → EMPLOYEE.emp_id (manager)

Attributes:
  • leave_type VARCHAR2(50) DEFAULT 'SICK'
  • leave_start DATE NOT NULL
  • leave_end DATE
  • reason VARCHAR2(255)
  • status VARCHAR2(20) DEFAULT 'PENDING' 
    CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'))
  • emp_id NUMBER NOT NULL
  • approved_by NUMBER

Constraints:
  • CHECK (leave_end >= leave_start OR leave_end IS NULL)
  • Checked via Compound Trigger TRG_LEAVE_STATUS_HANDLER
```

**Data Validation:**
- Compound trigger validates leave dates
- BEFORE EACH ROW: Ensures leave_start ≤ leave_end
- AFTER EACH ROW: Logs status changes (APPROVED, REJECTED)
- AFTER STATEMENT: Aggregates statistics

### 5. QUALIFICATION Table
**Purpose:** Stores employee certifications and training records
```sql
PK: qual_id (auto-generated via SEQ_QUALIFICATION starting at 5000)
FK: emp_id → EMPLOYEE.emp_id

Attributes:
  • qual_title VARCHAR2(150) NOT NULL
  • qual_type VARCHAR2(50) DEFAULT 'CERTIFICATION'
  • grant_date DATE
  • emp_id NUMBER NOT NULL
```

**Use Cases:**
- Training inventory management
- Compliance tracking (certifications validity)
- Skills-based reporting
- Career development planning

### 6. PAYROLL Table
**Purpose:** Centralized payroll transaction log
```sql
PK: payroll_id (auto-generated via SEQ_PAYROLL starting at 2000)
FK: emp_id → EMPLOYEE.emp_id
FK: job_id → JOB_DEPARTMENT.job_id
FK: salary_id → SALARY_BONUS.salary_id
FK: leave_id → LEAVE.leave_id

Attributes:
  • payroll_date DATE NOT NULL DEFAULT SYSDATE
  • gross_amount NUMBER(10,2) NOT NULL CHECK (gross_amount > 0)
  • deductions NUMBER(10,2) DEFAULT 0 CHECK (deductions >= 0)
  • net_amount NUMBER(10,2)
  • emp_id NUMBER NOT NULL
  • job_id NUMBER
  • salary_id NUMBER
  • leave_id NUMBER
  • payment_status VARCHAR2(20) DEFAULT 'PENDING'
    CHECK (payment_status IN ('PENDING', 'PROCESSED', 'PAID'))
```

**Validation Rules (BEFORE INSERT via TRG_VALIDATE_PAYROLL_INSERT):**
- Flags variance > 20% in PAYROLL_AUDIT
- Auto-calculates net_amount = gross_amount - deductions
- Archives all deduction details for audit

---

## Implementation Details

### 02_erd_mapping.sql - Schema & DDL
**Demonstrates:** 
- ✓ Full relational schema mapping (written format)
- ✓ 6 base tables with complete DDL
- ✓ 7 sequences for PK auto-increment
- ✓ 8 CHECK constraints (gender='M'|'F', salary>0, etc.)
- ✓ 5 indexes for query optimization (email, job_id, payroll dates)
- ✓ Cascading foreign keys with ON DELETE behavior

**Interview Talking Points:**
- Idempotent design: DROP before CREATE prevents ORA-00955 errors
- Sequences starting at different values (1, 100, 1000) for traceability
- CHECK constraints at table level ensure data integrity
- Indexes on FK columns improve JOIN performance
- Foreign key CASCADE prevents orphaned records

---

### 03_dml.sql - Data Manipulation & Transactions
**Demonstrates:**
- ✓ 12 employees across 5 departments
- ✓ 8 salary/bonus structures
- ✓ Leave and qualification records
- ✓ SAVEPOINT rollback recovery
- ✓ Batch INSERT with commit strategy

**Transaction Control Example:**
```sql
INSERT INTO PAYROLL (...) VALUES (...);  -- Valid record
SAVEPOINT before_second_payroll;         -- Create checkpoint
INSERT INTO PAYROLL (...) VALUES (-100); -- Invalid record
-- Error: CHECK constraint violation
ROLLBACK TO before_second_payroll;       -- Revert to checkpoint
INSERT INTO PAYROLL (...) VALUES (...);  -- Corrected record
COMMIT;                                  -- Final commit
```

**Business Context:**
- Prevents partially-processed payroll causing audit issues
- Demonstrates data integrity requirements
- Shows error recovery without full transaction loss

---

### 04_aggregation.sql - Reporting & Analytics
**Demonstrates:**
- ✓ GROUP BY with ROLLUP (subtotals + grand totals)
- ✓ CUBE for multi-dimensional analysis (dept × gender)
- ✓ DENSE_RANK() for salary rankings per department
- ✓ ROW_NUMBER() vs RANK() vs DENSE_RANK() comparison
- ✓ LEAD/LAG for salary gap analysis
- ✓ Window functions with ROWS BETWEEN for moving averages
- ✓ Payroll expense summaries with percentages

**Real-World Use Cases:**
```sql
-- Find top earners per department
DENSE_RANK() OVER (PARTITION BY dept_name ORDER BY salary DESC) as rank

-- Calculate salary increases
LAG(salary) OVER (ORDER BY salary DESC) as previous_higher_salary

-- Running payroll totals
SUM(gross) OVER (ORDER BY emp_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
```

---

### 05_joins.sql - Data Relationships
**Demonstrates:**
- ✓ INNER JOIN (matching records only)
- ✓ LEFT OUTER JOIN (all left + matching right)
- ✓ RIGHT OUTER JOIN (matching left + all right)
- ✓ FULL OUTER JOIN (all records from both tables)
- ✓ SELF JOIN (manager-subordinate relationships)
- ✓ CROSS JOIN (Cartesian product)
- ✓ ANTI JOIN with NOT EXISTS (orphaned record detection)

**Data Integrity Patterns:**
```sql
-- Find employees with no qualifications (ANTI JOIN)
WHERE NOT EXISTS (SELECT 1 FROM QUALIFICATION q WHERE q.emp_id = e.emp_id)

-- Complete employee profile (4-table join)
EMPLOYEE e 
  JOIN JOB_DEPARTMENT d ON e.job_id = d.job_id
  JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
  LEFT JOIN PAYROLL p ON e.emp_id = p.emp_id
```

---

### 06_subqueries.sql - Query Optimization
**Demonstrates:**
- ✓ Scalar subqueries (single value returns)
- ✓ Correlated subqueries (row-by-row comparisons)
- ✓ EXISTS for existence checking
- ✓ Derived tables (subquery in FROM clause)
- ✓ CTEs with WITH clause (multi-level)
- ✓ RECURSIVE CTEs for hierarchies
- ✓ INSERT...SELECT for bulk operations

**CTE Example - Employee Compensation Analysis:**
```sql
WITH dept_stats AS (
    -- Level 1: Department statistics
    SELECT job_id, AVG(amount) as avg_salary
    FROM SALARY_BONUS GROUP BY job_id
),
emp_ranking AS (
    -- Level 2: Rank employees per department
    SELECT emp_id, RANK() OVER (PARTITION BY job_id ORDER BY amount DESC) as rank
    FROM EMPLOYEE e JOIN dept_stats ds ON e.job_id = ds.job_id
)
SELECT * FROM emp_ranking WHERE rank <= 5;
```

**Performance Benefits:**
- CTEs are more readable than nested subqueries
- Oracle optimizer can materialize CTEs for complex queries
- Supports recursive hierarchies (org charts, BOMs)

---

### 07_views.sql - Data Abstraction & Security
**Demonstrates:**
- ✓ Simple views for data abstraction (VW_EMPLOYEE_DIRECTORY)
- ✓ Complex views with aggregation (VW_DEPARTMENT_STATS)
- ✓ Security-layer views (masked salary data)
- ✓ Materialized views for reporting (MVW_DEPARTMENT_SUMMARY)
- ✓ REFRESH COMPLETE ON DEMAND strategy
- ✓ INSTEAD OF triggers for view updates

**View Security Pattern:**
```sql
-- Public view (no salary data)
CREATE VIEW VW_EMPLOYEE_DIRECTORY AS
SELECT emp_id, first_name, last_name, email, dept_name, phone
FROM EMPLOYEE JOIN JOB_DEPARTMENT ...;

-- Finance view (with salary)
CREATE VIEW VW_SALARY_INFO AS
SELECT emp_id, total_compensation, bonus_amount
FROM EMPLOYEE JOIN SALARY_BONUS ...;
-- GRANT SELECT ON VW_SALARY_INFO TO role_finance;
```

**Materialized View Strategy:**
- MVW_DEPARTMENT_SUMMARY: Pre-aggregated department metrics
- MVW_MONTHLY_PAYROLL: Historical payroll snapshots
- REFRESH ON DEMAND: Allows scheduled refreshes without view lock

---

### 08_procedures.sql - Server-Side Logic
**Demonstrates:**
- ✓ Standalone procedure: SP_ADD_EMPLOYEE (parameter validation)
- ✓ Standalone function: FN_CALCULATE_NET_SALARY (calculation)
- ✓ PL/SQL Package: PKG_EMS (namespace encapsulation)
- ✓ Error handling with RAISE_APPLICATION_ERROR
- ✓ RETURNING clause for ID retrieval
- ✓ Package specification & body separation

**Procedure Example - Add Employee:**
```sql
CREATE PROCEDURE SP_ADD_EMPLOYEE(
    p_first_name IN VARCHAR2,
    p_gender IN CHAR,
    p_emp_id OUT NUMBER
) AS
BEGIN
    IF p_gender NOT IN ('M', 'F') THEN
        RAISE_APPLICATION_ERROR(-20002, 'Invalid gender');
    END IF;
    
    INSERT INTO EMPLOYEE (...) VALUES (...)
    RETURNING emp_id INTO p_emp_id;
    COMMIT;
END;
```

**Package Architecture Benefits:**
- Procedures and functions grouped logically
- Single EXECUTE privilege grants access to all routines
- Version control simplified (one code object)
- Improved maintainability vs. standalone procs

---

### 09_triggers.sql - Automated Enforcement
**Demonstrates:**
- ✓ BEFORE UPDATE trigger: TRG_SALARY_NO_DECREASE (prevent salary cuts)
- ✓ AFTER DELETE trigger: TRG_ARCHIVE_DELETED_EMPLOYEE (audit trail)
- ✓ BEFORE INSERT trigger: TRG_VALIDATE_PAYROLL_INSERT (validation)
- ✓ Compound trigger: TRG_LEAVE_STATUS_HANDLER (multi-step logic)
- ✓ INSTEAD OF trigger: View update redirection
- ✓ Audit tables: EMPLOYEE_ARCHIVE, SALARY_AUDIT_LOG, PAYROLL_AUDIT

**BEFORE UPDATE Example - Salary Protection:**
```sql
CREATE TRIGGER TRG_SALARY_NO_DECREASE
    BEFORE UPDATE ON SALARY_BONUS FOR EACH ROW
BEGIN
    IF :NEW.amount < :OLD.amount THEN
        RAISE_APPLICATION_ERROR(-20100, 
            'Salary Cut Blocked: $' || :OLD.amount || ' → $' || :NEW.amount);
    END IF;
    
    -- Audit the change
    INSERT INTO SALARY_AUDIT_LOG (...) 
    VALUES (:NEW.salary_id, :OLD.amount, :NEW.amount, ...);
END;
```

**Compound Trigger - Leave Status Management:**
```sql
CREATE TRIGGER TRG_LEAVE_STATUS_HANDLER FOR ... COMPOUND TRIGGER
    BEFORE EACH ROW IS    -- Row-level validation
    AFTER EACH ROW IS     -- Row-level logging
    AFTER STATEMENT IS    -- Statement-level aggregation END;
```

**Trigger Use Cases:**
- Data validation (CHECK constraints + triggers)
- Audit trail maintenance
- Automatic calculations (net_amount = gross - deductions)
- Business rule enforcement
- Status lifecycle management

---

### 10_scheduler.sql - Automation Framework
**Demonstrates:**
- ✓ 4 scheduled job procedures (audit, reporting, cleanup)
- ✓ 3 DBMS_SCHEDULER jobs (daily, weekly, monthly)
- ✓ Multi-step chain: CHAIN_PAYROLL_PIPELINE (5 steps)
- ✓ Job execution logging (timing, status, counts)
- ✓ Success rate tracking and monitoring
- ✓ Program objects for reusability

**Job Procedures:**
```sql
SP_JOB_DAILY_PAYROLL_AUDIT
  └─ Validates payroll completeness
  └─ Checks for amount variances > 20%
  └─ Logs results to JOB_EXECUTION_LOG

SP_JOB_WEEKLY_LEAVE_REPORT
  └─ Counts approved vs. pending leaves
  └─ Identifies overdue leave approvals
  
SP_JOB_MONTHLY_CLEANUP
  └─ Archives old records
  └─ Purges rejected leave requests (6+ months old)
  
SP_JOB_VALIDATION_REPORT
  └─ Summarizes data quality issues
  └─ Tracks validation exceptions
```

**Scheduler Chain - Payroll Pipeline:**
```
START 
  ↓
STEP_01_VALIDATION     (Data integrity checks)
  ↓
STEP_02_PROCESSING     (Payroll calculations)
  ↓
STEP_03_AUDITING       (Audit trail logging)
  ↓
STEP_04_REPORTING      (Generate reports)
  ↓
END
```

**Production Deployment:**
```sql
-- Enable job (currently disabled for demo)
DBMS_SCHEDULER.ENABLE('JOB_DAILY_AUDIT');

-- Monitor job execution
SELECT * FROM user_scheduler_job_run_details 
WHERE job_name = 'JOB_DAILY_AUDIT' 
ORDER BY actual_start_date DESC;
```

---

## Performance Considerations

### Index Strategy
```sql
CREATE INDEX idx_emp_email ON EMPLOYEE(email);        -- Rapid lookup
CREATE INDEX idx_emp_job ON EMPLOYEE(job_id);         -- JOIN optimization
CREATE INDEX idx_payroll_emp ON PAYROLL(emp_id);      -- FK queries
CREATE INDEX idx_payroll_date ON PAYROLL(payroll_date); -- Temporal queries
CREATE INDEX idx_leave_emp ON LEAVE(emp_id);          -- Leave lookup
```

**Query Performance Tips:**
- Use EXPLAIN PLAN to verify index usage
- Avoid full table scans on large transactions
- Partition PAYROLL table by payroll_date (monthly)
- Archive old payroll records (> 5 years) separately
- Use materialized views for frequently-run reports

### Scalability Recommendations
| Scale | Action |
|-------|--------|
| 1,000 employees | Current design adequate |
| 10,000 employees | Add table partitioning on PAYROLL |
| 100,000 employees | Consider sharding; archive transactions |
| 1M+ employees | Enterprise partitioning; data warehouse design |

---

## Security & Compliance

### Data Access Control
```sql
-- Create roles
CREATE ROLE role_hr_manager;
CREATE ROLE role_payroll_admin;
CREATE ROLE role_employee;

-- Grant view access
GRANT SELECT ON VW_EMPLOYEE_DIRECTORY TO role_employee;
GRANT SELECT ON VW_SALARY_INFO TO role_payroll_admin;
GRANT EXECUTE ON PKG_EMS TO role_hr_manager;
```

### Compliance Features

**1. Audit Trail:**
- EMPLOYEE_ARCHIVE: Deleted employee records with timestamp
- SALARY_AUDIT_LOG: All salary changes with before/after values
- PAYROLL_AUDIT: Validation warnings and exceptions
- JOB_EXECUTION_LOG: Scheduled task audit

**2. Data Masking:**
- Views abstract sensitive columns (salary)
- Email, phone partly obscured in directory views

**3. Constraints & Validation:**
- Gender: 'M' or 'F' only (database-level)
- Salary: must be positive (CHECK constraint)
- Age: 18-75 range (CHECK constraint)
- Leave dates: start ≤ end (trigger validation)
- Payroll variance: > 20% flagged (trigger audit)

---

## Deployment Guide

### Step 1: Prerequisites
```bash
# Oracle 19c installation
# SQL*Plus or SQL Developer with DBA privileges
# At least 100MB tablespace for EMS schema
```

### Step 2: Script Execution Order
```sql
-- 1. Create schema and tables
@01_erd_mapping.sql

-- 2. Review normalization (informational)
@02_normalization.sql

-- 3. Insert test data
@03_dml.sql

-- 4. Create views
@07_views.sql

-- 5. Create procedures and package
@08_procedures.sql

-- 6. Create triggers
@09_triggers.sql

-- 7. Create aggregation queries
@04_aggregation.sql
@05_joins.sql
@06_subqueries.sql

-- 8. Set up scheduler
@10_scheduler.sql
```

### Step 3: Verification Checklist
```sql
-- Verify tables
SELECT COUNT(*) FROM user_tables WHERE table_name LIKE '%_PARTITION' = 0;  -- 6 tables

-- Verify data
SELECT COUNT(*) FROM EMPLOYEE;         -- Should be ≥ 12
SELECT COUNT(*) FROM PAYROLL;          -- Should be ≥ 12
SELECT COUNT(DISTINCT job_id) FROM JOB_DEPARTMENT;  -- Should be 5

-- Verify triggers
SELECT COUNT(*) FROM user_triggers WHERE trigger_name LIKE 'TRG_%' AND status = 'ENABLED';
-- Should be 6

-- Verify views
SELECT COUNT(*) FROM user_views WHERE view_name LIKE 'VW_%';  -- Should be 6
SELECT COUNT(*) FROM user_mviews WHERE mview_name LIKE 'MVW_%';  -- Should be 3
```

### Step 4: Test Execution
```sql
-- Test package procedure
DECLARE v_result VARCHAR2(500);
BEGIN
  PKG_EMS.proc_add_employee('Test', 'User', 'M', 30, 'test@ems.com', 
                            '555-9999', 1, 100, v_result);
  DBMS_OUTPUT.PUT_LINE(v_result);
END;
/

-- Test view query
SELECT COUNT(*) FROM VW_EMPLOYEE_PROFILE;

-- Test aggregation
SELECT dept_name, COUNT(*), ROUND(AVG(total_compensation), 2)
FROM VW_EMPLOYEE_PROFILE
GROUP BY dept_name;
```

---

## Troubleshooting

### Common Issues & Solutions

**Issue:** ORA-00955 Name is already used by existing object
```sql
-- Solution: Add idempotent cleanup at script beginning
BEGIN
  FOR r IN (SELECT table_name FROM user_tables WHERE table_name = 'EMPLOYEE') 
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || r.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
```

**Issue:** ORA-00001 Unique constraint violated
```sql
-- Solution: Verify email uniqueness before insert
SELECT * FROM EMPLOYEE WHERE email = 'duplicate@ems.com';
```

**Issue:** Trigger compilation errors
```sql
-- Solution: Check trigger dependencies and syntax
SELECT * FROM user_errors WHERE name LIKE 'TRG_%';
```

**Issue:** Scheduler jobs not running
```sql
-- Solution: Check privilege grants
GRANT EXECUTE ON DBMS_SCHEDULER TO username;
-- Enable job explicitly
DBMS_SCHEDULER.ENABLE('JOB_DAILY_AUDIT');
```




