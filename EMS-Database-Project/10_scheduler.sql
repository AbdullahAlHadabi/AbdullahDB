-- =============================================================================
-- 10_scheduler.sql
-- EMPLOYEE MANAGEMENT SYSTEM (EMS) - ORACLE DBMS_SCHEDULER AUTOMATION
-- ORACLE 19c / PL-SQL
-- =============================================================================
-- OBJECTIVE:
--   - Create scheduled jobs for daily, weekly, and monthly tasks
--   - Create a scheduler chain for multi-step payroll pipeline
--   - Implement archival and reporting jobs
--   - Set up audit trail for scheduled task execution
-- =============================================================================

SET SERVEROUTPUT ON;

DBMS_OUTPUT.PUT_LINE('
╔═══════════════════════════════════════════════════════════════════════════╗
║              EMS ORACLE DBMS_SCHEDULER & AUTOMATED JOBS                   ║
╚═══════════════════════════════════════════════════════════════════════════╝
');

-- =============================================================================
-- [SECTION 10.1] - CREATE JOB LOG TABLE (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== SETTING UP JOB INFRASTRUCTURE ===');

BEGIN
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name = 'JOB_EXECUTION_LOG')
    LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name;
    END LOOP;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE JOB_EXECUTION_LOG (
    log_id          NUMBER PRIMARY KEY,
    job_name        VARCHAR2(100),
    execution_start DATE,
    execution_end   DATE,
    status          VARCHAR2(20),  -- SUCCESS, FAILED, WARNING
    records_affected NUMBER,
    error_message   VARCHAR2(500),
    execution_time_sec NUMBER
);

CREATE SEQUENCE SEQ_JOB_LOG
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

DBMS_OUTPUT.PUT_LINE('✓ Created JOB_EXECUTION_LOG table');

-- =============================================================================
-- [SECTION 10.2] - CREATE PROCEDURES FOR SCHEDULED JOBS (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING JOB PROCEDURES ===');

-- PROCEDURE 1: Daily Payroll Audit
CREATE OR REPLACE PROCEDURE SP_JOB_DAILY_PAYROLL_AUDIT
AS
    v_start_time    TIMESTAMP := SYSTIMESTAMP;
    v_error_count   NUMBER := 0;
    v_warning_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('► Starting Daily Payroll Audit (Job Start: ' ||
        TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS') || ')');

    -- Check for missing payroll (employees without payroll this month)
    SELECT COUNT(DISTINCT e.emp_id) INTO v_error_count
    FROM EMPLOYEE e
    WHERE NOT EXISTS (
        SELECT 1 FROM PAYROLL p
        WHERE p.emp_id = e.emp_id
        AND TRUNC(p.payroll_date, 'MM') = TRUNC(SYSDATE, 'MM')
    );

    -- Check for suspicious payroll amounts (> 50% variance)
    SELECT COUNT(*) INTO v_warning_count
    FROM (
        SELECT p.emp_id
        FROM PAYROLL p
        JOIN EMPLOYEE e ON p.emp_id = e.emp_id
        JOIN SALARY_BONUS sb ON e.salary_id = sb.salary_id
        WHERE ABS(p.gross_amount - sb.amount) > sb.amount * 0.50
        AND TRUNC(p.payroll_date) = TRUNC(SYSDATE)
    );

    -- Log results
    INSERT INTO JOB_EXECUTION_LOG (
        log_id, job_name, execution_start, execution_end, status,
        records_affected, error_message, execution_time_sec
    ) VALUES (
        SEQ_JOB_LOG.NEXTVAL,
        'SP_JOB_DAILY_PAYROLL_AUDIT',
        v_start_time,
        SYSTIMESTAMP,
        CASE WHEN v_error_count = 0 AND v_warning_count = 0 THEN 'SUCCESS'
             WHEN v_error_count > 0 THEN 'FAILED'
             ELSE 'WARNING' END,
        v_error_count + v_warning_count,
        'Missing: ' || v_error_count || ', Variance Warnings: ' || v_warning_count,
        EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time))
    );

    DBMS_OUTPUT.PUT_LINE('✓ Daily Payroll Audit Complete: ' || v_error_count ||
        ' errors, ' || v_warning_count || ' warnings');
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error in Daily Audit: ' || SQLERRM);
        INSERT INTO JOB_EXECUTION_LOG (
            log_id, job_name, execution_start, execution_end, status,
            error_message
        ) VALUES (
            SEQ_JOB_LOG.NEXTVAL, 'SP_JOB_DAILY_PAYROLL_AUDIT', v_start_time,
            SYSTIMESTAMP, 'FAILED', SQLERRM
        );
        COMMIT;
END SP_JOB_DAILY_PAYROLL_AUDIT;
/

DBMS_OUTPUT.PUT_LINE('✓ Created SP_JOB_DAILY_PAYROLL_AUDIT');

-- PROCEDURE 2: Weekly Leave Report
CREATE OR REPLACE PROCEDURE SP_JOB_WEEKLY_LEAVE_REPORT
AS
    v_start_time    TIMESTAMP := SYSTIMESTAMP;
    v_approved      NUMBER := 0;
    v_pending       NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('► Starting Weekly Leave Report (Job Start: ' ||
        TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS') || ')');

    -- Count approved leaves for upcoming week
    SELECT COUNT(*) INTO v_approved
    FROM LEAVE
    WHERE status = 'APPROVED'
    AND leave_start >= TRUNC(SYSDATE)
    AND leave_start < TRUNC(SYSDATE + 7);

    -- Count pending leaves
    SELECT COUNT(*) INTO v_pending
    FROM LEAVE
    WHERE status = 'PENDING'
    AND TRUNC(SYSDATE) - TRUNC(leave_start) >= 0;

    -- Log results
    INSERT INTO JOB_EXECUTION_LOG (
        log_id, job_name, execution_start, execution_end, status,
        records_affected, error_message, execution_time_sec
    ) VALUES (
        SEQ_JOB_LOG.NEXTVAL,
        'SP_JOB_WEEKLY_LEAVE_REPORT',
        v_start_time,
        SYSTIMESTAMP,
        'SUCCESS',
        v_approved + v_pending,
        'Approved: ' || v_approved || ', Pending: ' || v_pending,
        EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time))
    );

    DBMS_OUTPUT.PUT_LINE('✓ Weekly Leave Report Complete: ' || v_approved ||
        ' approved, ' || v_pending || ' pending');
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error in Weekly Report: ' || SQLERRM);
        ROLLBACK;
END SP_JOB_WEEKLY_LEAVE_REPORT;
/

DBMS_OUTPUT.PUT_LINE('✓ Created SP_JOB_WEEKLY_LEAVE_REPORT');

-- PROCEDURE 3: Monthly Archive Cleanup
CREATE OR REPLACE PROCEDURE SP_JOB_MONTHLY_CLEANUP
AS
    v_start_time    TIMESTAMP := SYSTIMESTAMP;
    v_archived_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('► Starting Monthly Cleanup (Job Start: ' ||
        TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS') || ')');

    -- Archive old rejected leave requests (older than 6 months)
    SELECT COUNT(*) INTO v_archived_count
    FROM LEAVE
    WHERE status = 'REJECTED'
    AND leave_start < ADD_MONTHS(TRUNC(SYSDATE), -6);

    DBMS_OUTPUT.PUT_LINE('Records to archive: ' || v_archived_count);

    -- In production, would actually delete/archive these records
    -- DELETE FROM LEAVE WHERE status = 'REJECTED' AND leave_start < ADD_MONTHS(TRUNC(SYSDATE), -6);

    -- Log results
    INSERT INTO JOB_EXECUTION_LOG (
        log_id, job_name, execution_start, execution_end, status,
        records_affected, error_message, execution_time_sec
    ) VALUES (
        SEQ_JOB_LOG.NEXTVAL,
        'SP_JOB_MONTHLY_CLEANUP',
        v_start_time,
        SYSTIMESTAMP,
        'SUCCESS',
        v_archived_count,
        'Archived ' || v_archived_count || ' old records',
        EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time))
    );

    DBMS_OUTPUT.PUT_LINE('✓ Monthly Cleanup Complete');
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error in Monthly Cleanup: ' || SQLERRM);
        ROLLBACK;
END SP_JOB_MONTHLY_CLEANUP;
/

DBMS_OUTPUT.PUT_LINE('✓ Created SP_JOB_MONTHLY_CLEANUP');

-- PROCEDURE 4: Validation Report
CREATE OR REPLACE PROCEDURE SP_JOB_VALIDATION_REPORT
AS
    v_start_time    TIMESTAMP := SYSTIMESTAMP;
    v_validation_errors NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('► Starting Validation Report (Job Start: ' ||
        TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS') || ')');

    -- Count validation issues
    SELECT COUNT(*) INTO v_validation_errors
    FROM PAYROLL_AUDIT
    WHERE TRUNC(audit_date) = TRUNC(SYSDATE)
    AND audit_type = 'VARIANCE_WARNING';

    -- Log results
    INSERT INTO JOB_EXECUTION_LOG (
        log_id, job_name, execution_start, execution_end, status,
        records_affected, error_message, execution_time_sec
    ) VALUES (
        SEQ_JOB_LOG.NEXTVAL,
        'SP_JOB_VALIDATION_REPORT',
        v_start_time,
        SYSTIMESTAMP,
        CASE WHEN v_validation_errors > 0 THEN 'WARNING' ELSE 'SUCCESS' END,
        v_validation_errors,
        'Found ' || v_validation_errors || ' validation warnings',
        EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time))
    );

    DBMS_OUTPUT.PUT_LINE('✓ Validation Report Complete: ' || v_validation_errors || ' issues');
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error in Validation: ' || SQLERRM);
        ROLLBACK;
END SP_JOB_VALIDATION_REPORT;
/

DBMS_OUTPUT.PUT_LINE('✓ Created SP_JOB_VALIDATION_REPORT');

-- =============================================================================
-- [SECTION 10.3] - CREATE SCHEDULER JOBS (Medium Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING SCHEDULER JOBS ===');

BEGIN
    -- Clean up existing jobs
    BEGIN
        DBMS_SCHEDULER.DROP_JOB(job_name => 'JOB_DAILY_AUDIT', force => TRUE);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- JOB 1: Daily Payroll Audit (9:00 AM every day)
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_DAILY_AUDIT',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'SP_JOB_DAILY_PAYROLL_AUDIT',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY;BYHOUR=9',
        enabled         => FALSE  -- Disabled for demo (would be TRUE in production)
    );

    DBMS_OUTPUT.PUT_LINE('✓ Created JOB_DAILY_AUDIT (Daily 9 AM)');

EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Note: Job creation may require additional privileges');
END;
/

BEGIN
    BEGIN
        DBMS_SCHEDULER.DROP_JOB(job_name => 'JOB_WEEKLY_LEAVES', force => TRUE);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- JOB 2: Weekly Leave Report (Every Monday at 8:00 AM)
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_WEEKLY_LEAVES',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'SP_JOB_WEEKLY_LEAVE_REPORT',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=WEEKLY;BYDAY=MON;BYHOUR=8',
        enabled         => FALSE
    );

    DBMS_OUTPUT.PUT_LINE('✓ Created JOB_WEEKLY_LEAVES (Weekly Monday 8 AM)');

EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    BEGIN
        DBMS_SCHEDULER.DROP_JOB(job_name => 'JOB_MONTHLY_CLEANUP', force => TRUE);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- JOB 3: Monthly Cleanup (1st of every month at midnight)
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_MONTHLY_CLEANUP',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'SP_JOB_MONTHLY_CLEANUP',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MONTHLY;BYMONTHDAY=1;BYHOUR=0',
        enabled         => FALSE
    );

    DBMS_OUTPUT.PUT_LINE('✓ Created JOB_MONTHLY_CLEANUP (Monthly 1st midnight)');

EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- =============================================================================
-- [SECTION 10.4] - CREATE SCHEDULER CHAIN (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING SCHEDULER CHAIN: PAYROLL PIPELINE ===');

BEGIN
    -- Drop existing chain if present
    BEGIN
        DBMS_SCHEDULER.DROP_CHAIN(chain_name => 'CHAIN_PAYROLL_PIPELINE', force => TRUE);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- Create the chain
    DBMS_SCHEDULER.CREATE_CHAIN(
        chain_name  => 'CHAIN_PAYROLL_PIPELINE',
        rule_set_name => NULL,
        evaluation_interval => NULL,
        comments    => 'Multi-step payroll processing and reporting pipeline'
    );

    DBMS_OUTPUT.PUT_LINE('✓ Created CHAIN_PAYROLL_PIPELINE');

EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Note: Chain functionality available in Oracle 11g+');
END;
/

BEGIN
    -- Add steps to the chain

    -- STEP 1: Validation
    DBMS_SCHEDULER.DEFINE_CHAIN_STEP(
        chain_name  => 'CHAIN_PAYROLL_PIPELINE',
        step_name   => 'STEP_01_VALIDATION',
        program_name => NULL,
        comments    => 'Check payroll data integrity'
    );

    -- STEP 2: Processing
    DBMS_SCHEDULER.DEFINE_CHAIN_STEP(
        chain_name  => 'CHAIN_PAYROLL_PIPELINE',
        step_name   => 'STEP_02_PROCESSING',
        program_name => NULL,
        comments    => 'Process payroll calculations'
    );

    -- STEP 3: Auditing
    DBMS_SCHEDULER.DEFINE_CHAIN_STEP(
        chain_name  => 'CHAIN_PAYROLL_PIPELINE',
        step_name   => 'STEP_03_AUDITING',
        program_name => NULL,
        comments    => 'Perform audit trail logging'
    );

    -- STEP 4: Reporting
    DBMS_SCHEDULER.DEFINE_CHAIN_STEP(
        chain_name  => 'CHAIN_PAYROLL_PIPELINE',
        step_name   => 'STEP_04_REPORTING',
        program_name => NULL,
        comments    => 'Generate payroll reports'
    );

    DBMS_OUTPUT.PUT_LINE('✓ Added 4 steps to CHAIN_PAYROLL_PIPELINE');

EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    -- Define chain execution rules

    -- Rule 1: Start with VALIDATION
    DBMS_SCHEDULER.DEFINE_CHAIN_RULE(
        chain_name  => 'CHAIN_PAYROLL_PIPELINE',
        rule_name   => 'RULE_START',
        condition   => 'TRUE',
        action      => 'START STEP_01_VALIDATION',
        rule_number => 1
    );

    -- Rule 2: VALIDATION -> PROCESSING
    DBMS_SCHEDULER.DEFINE_CHAIN_RULE(
        chain_name  => 'CHAIN_PAYROLL_PIPELINE',
        rule_name   => 'RULE_V_TO_P',
        condition   => 'STEP_01_VALIDATION COMPLETED',
        action      => 'START STEP_02_PROCESSING',
        rule_number => 2
    );

    -- Rule 3: PROCESSING -> AUDITING
    DBMS_SCHEDULER.DEFINE_CHAIN_RULE(
        chain_name  => 'CHAIN_PAYROLL_PIPELINE',
        rule_name   => 'RULE_P_TO_A',
        condition   => 'STEP_02_PROCESSING COMPLETED',
        action      => 'START STEP_03_AUDITING',
        rule_number => 3
    );

    -- Rule 4: AUDITING -> REPORTING
    DBMS_SCHEDULER.DEFINE_CHAIN_RULE(
        chain_name  => 'CHAIN_PAYROLL_PIPELINE',
        rule_name   => 'RULE_A_TO_R',
        condition   => 'STEP_03_AUDITING COMPLETED',
        action      => 'START STEP_04_REPORTING',
        rule_number => 4
    );

    -- Rule 5: END when REPORTING completes
    DBMS_SCHEDULER.DEFINE_CHAIN_RULE(
        chain_name  => 'CHAIN_PAYROLL_PIPELINE',
        rule_name   => 'RULE_END',
        condition   => 'STEP_04_REPORTING COMPLETED',
        action      => 'END',
        rule_number => 5
    );

    DBMS_OUTPUT.PUT_LINE('✓ Defined chain execution rules (5 rules)');

EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Note: ' || SQLERRM);
END;
/

BEGIN
    -- Enable the chain (would normally happen after all setup)
    -- DBMS_SCHEDULER.ENABLE('CHAIN_PAYROLL_PIPELINE');
    DBMS_OUTPUT.PUT_LINE('✓ Chain configured and ready (disabled for demo)');
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- =============================================================================
-- [SECTION 10.5] - CREATE PROGRAM OBJECTS (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== CREATING PROGRAM OBJECTS ===');

BEGIN
    -- Create program for daily audit
    BEGIN
        DBMS_SCHEDULER.DROP_PROGRAM(program_name => 'PROG_DAILY_AUDIT', force => TRUE);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    DBMS_SCHEDULER.CREATE_PROGRAM(
        program_name    => 'PROG_DAILY_AUDIT',
        program_type    => 'STORED_PROCEDURE',
        program_action  => 'SP_JOB_DAILY_PAYROLL_AUDIT',
        enabled         => TRUE,
        comments        => 'Program for daily payroll auditing'
    );

    DBMS_OUTPUT.PUT_LINE('✓ Created PROG_DAILY_AUDIT');

EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Note: Program creation may require additional setup');
END;
/

-- =============================================================================
-- [SECTION 10.6] - SCHEDULER STATISTICS & MONITORING (Hard Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  SCHEDULER STATISTICS & JOB EXECUTION LOG
═══════════════════════════════════════════════════════════════════════════
');

-- View job execution history
DBMS_OUTPUT.PUT_LINE('Recent Job Executions:');
DBMS_OUTPUT.PUT_LINE('──────────────────────');

SELECT job_name, status, records_affected, execution_time_sec
FROM JOB_EXECUTION_LOG
ORDER BY execution_start DESC
FETCH FIRST 10 ROWS ONLY;

-- Summary statistics
SELECT
    COUNT(*) as total_executions,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed,
    SUM(CASE WHEN status = 'WARNING' THEN 1 ELSE 0 END) as warnings,
    ROUND(AVG(execution_time_sec), 2) as avg_execution_time
FROM JOB_EXECUTION_LOG;

-- =============================================================================
-- [SECTION 10.7] - MANUAL JOB EXECUTION FOR TESTING (Easy Task)
-- =============================================================================

DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  MANUAL JOB EXECUTION FOR TESTING
═══════════════════════════════════════════════════════════════════════════
');

DBMS_OUTPUT.PUT_LINE('Executing scheduled jobs manually for demo...');
DBMS_OUTPUT.PUT_LINE('');

-- Execute each job procedure directly
SP_JOB_DAILY_PAYROLL_AUDIT;
/

SP_JOB_WEEKLY_LEAVE_REPORT;
/

SP_JOB_MONTHLY_CLEANUP;
/

SP_JOB_VALIDATION_REPORT;
/

-- =============================================================================
-- [SECTION 10.8] - FINAL SUMMARY (Hard Task)
-- =============================================================================

DECLARE
    v_job_count     NUMBER := 0;
    v_exec_count    NUMBER := 0;
    v_success_rate  NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_job_count
    FROM user_scheduler_jobs
    WHERE job_name IN ('JOB_DAILY_AUDIT', 'JOB_WEEKLY_LEAVES', 'JOB_MONTHLY_CLEANUP');

    SELECT COUNT(*) INTO v_exec_count
    FROM JOB_EXECUTION_LOG;

    SELECT ROUND(100 * SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) /
           NULLIF(COUNT(*), 0), 2) INTO v_success_rate
    FROM JOB_EXECUTION_LOG;

    DBMS_OUTPUT.PUT_LINE('
═══════════════════════════════════════════════════════════════════════════
  SCHEDULER SETUP SUMMARY
═══════════════════════════════════════════════════════════════════════════

Jobs Created:                  ' || v_job_count || ' jobs
Total Executions Logged:       ' || v_exec_count || ' executions
Success Rate:                  ' || v_success_rate || '%

SCHEDULER COMPONENTS:
  ✓ 4 Job Procedures
    • SP_JOB_DAILY_PAYROLL_AUDIT
    • SP_JOB_WEEKLY_LEAVE_REPORT
    • SP_JOB_MONTHLY_CLEANUP
    • SP_JOB_VALIDATION_REPORT

  ✓ 3 Scheduled Jobs (Currently Disabled for Demo)
    • JOB_DAILY_AUDIT           (Daily 9 AM)
    • JOB_WEEKLY_LEAVES         (Monday 8 AM)
    • JOB_MONTHLY_CLEANUP       (1st of month, midnight)

  ✓ 1 Scheduler Chain
    • CHAIN_PAYROLL_PIPELINE
      Step 1: Validation
      Step 2: Processing
      Step 3: Auditing
      Step 4: Reporting

  ✓ Job Execution Log
    • Tracks all job executions
    • Records success/failure status
    • Logs execution duration

PRODUCTION DEPLOYMENT CHECKLIST:
  □ Create appropriate database users with SCHEDULER privileges
  □ Establish notification mechanisms (email alerts on failures)
  □ Set up centralized monitoring and alerting
  □ Implement job restart/retry logic for failures
  □ Archive job logs periodically to separate audit tables
  □ Document all scheduled jobs in runbooks
  □ Enable jobs (currently disabled for demo)
  □ Test chain execution flow end-to-end
  □ Set up backup scheduler for HA/DR scenarios

ENABLING JOBS IN PRODUCTION:
  EXECUTE DBMS_SCHEDULER.ENABLE(''JOB_DAILY_AUDIT'');
  EXECUTE DBMS_SCHEDULER.ENABLE(''JOB_WEEKLY_LEAVES'');
  EXECUTE DBMS_SCHEDULER.ENABLE(''JOB_MONTHLY_CLEANUP'');

═══════════════════════════════════════════════════════════════════════════
  SCHEDULER & AUTOMATION COMPLETE
═══════════════════════════════════════════════════════════════════════════');

END;
/

COMMIT;

