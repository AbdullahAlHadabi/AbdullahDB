/* =================================================================
   ORACLE SQL SUBQUERY - LOGIC REVIEW & EXECUTION ANALYSIS
   -----------------------------------------------------------------
   Copy-paste ready for IntelliJ / DataGrip / SQL Developer.
   Run against the standard Oracle HR sample schema.
   ================================================================= */


-- ##################################################################
-- ## QUERY REVIEW 1 - Aggregate in WHERE (ORA-00934)
-- ##################################################################

-- ORIGINAL (BROKEN): ORA-00934: group function is not allowed here
-- Aggregates cannot be used in WHERE because WHERE runs before aggregation.
/*
SELECT first_name, salary
FROM   employees
WHERE  salary > AVG(salary);
*/

-- FIXED: Use a scalar subquery so AVG is computed first as a single value
SELECT first_name, salary
FROM   employees
WHERE  salary > (SELECT AVG(salary) FROM employees)
ORDER  BY salary DESC;
-- Subquery type: SCALAR SUBQUERY (returns one row, one column)



-- ##################################################################
-- ## QUERY REVIEW 2 - Single-row operator with multi-row subquery
-- ##################################################################

-- ORIGINAL (BROKEN): ORA-01427: single-row subquery returns more than one row
-- The "=" operator expects one value, but the subquery returns 107 rows.
/*
SELECT department_name
FROM   departments
WHERE  department_id = (
           SELECT department_id
           FROM   employees
       );
*/

-- FIX OPTION A: Use IN for a multi-row subquery
SELECT department_name
FROM   departments
WHERE  department_id IN (
           SELECT DISTINCT department_id
           FROM   employees
           WHERE  department_id IS NOT NULL
       )
ORDER  BY department_name;
-- Subquery type: MULTI-ROW SUBQUERY with IN

-- FIX OPTION B (recommended): Use EXISTS - NULL-safe and often faster
SELECT d.department_name
FROM   departments d
WHERE  EXISTS (
           SELECT 1
           FROM   employees e
           WHERE  e.department_id = d.department_id
       )
ORDER  BY d.department_name;
-- Subquery type: CORRELATED SUBQUERY with EXISTS



-- ##################################################################
-- ## QUERY REVIEW 3 - Wrong column compared (SILENT BUG)
-- ##################################################################

-- ORIGINAL (SILENTLY WRONG): runs without error but returns meaningless data
-- Comparing department_id (10, 20, 30...) against salary (2500, 4800, ...)
-- The two value domains do not overlap meaningfully.
/*
SELECT *
FROM   employees
WHERE  department_id IN (
           SELECT salary
           FROM   employees
       );
*/

-- POSSIBLE INTENT A: Employees in departments that have more than one employee
SELECT *
FROM   employees
WHERE  department_id IN (
           SELECT department_id
           FROM   employees
           WHERE  department_id IS NOT NULL
           GROUP  BY department_id
           HAVING COUNT(*) > 1
       );

-- POSSIBLE INTENT B: Employees whose department actually exists in departments table
SELECT *
FROM   employees
WHERE  department_id IN (
           SELECT department_id
           FROM   departments
       );

-- POSSIBLE INTENT C: Employees earning the same salary as someone in dept 50
SELECT *
FROM   employees
WHERE  salary IN (
           SELECT salary
           FROM   employees
           WHERE  department_id = 50
       );

-- Subquery type: MULTI-ROW SUBQUERY (structure was fine, columns were wrong)
-- Reviewer action: REJECT and ask the author to clarify business intent.



-- ##################################################################
-- ## QUERY REVIEW 4 - Subquery returns many rows with ">" operator
-- ##################################################################

-- ORIGINAL (BROKEN): ORA-01427 - department 90 has 3 employees
/*
SELECT first_name
FROM   employees
WHERE  salary > (
           SELECT salary
           FROM   employees
           WHERE  department_id = 90
       );
*/

-- INTERPRETATION A: Earn more than EVERY employee in dept 90 (above the highest)
SELECT first_name, salary
FROM   employees
WHERE  salary > ALL (
           SELECT salary
           FROM   employees
           WHERE  department_id = 90
       )
ORDER  BY salary DESC;
-- Equivalent to:  salary > (SELECT MAX(salary) FROM employees WHERE department_id = 90)

-- INTERPRETATION B: Earn more than AT LEAST ONE employee in dept 90 (above the lowest)
SELECT first_name, salary
FROM   employees
WHERE  salary > ANY (
           SELECT salary
           FROM   employees
           WHERE  department_id = 90
       )
ORDER  BY salary DESC;
-- Equivalent to:  salary > (SELECT MIN(salary) FROM employees WHERE department_id = 90)

-- INTERPRETATION C (most common business intent): More than the AVERAGE of dept 90
SELECT first_name, salary
FROM   employees
WHERE  salary > (
           SELECT AVG(salary)
           FROM   employees
           WHERE  department_id = 90
       )
ORDER  BY salary DESC;
-- Subquery type: SCALAR SUBQUERY with AVG



-- ##################################################################
-- ## BONUS - Quick verification queries
-- ##################################################################

-- Verify how many employees are in dept 90 (to confirm Review 4's diagnosis)
SELECT COUNT(*) AS emp_in_dept_90,
       MIN(salary) AS min_sal,
       AVG(salary) AS avg_sal,
       MAX(salary) AS max_sal
FROM   employees
WHERE  department_id = 90;

-- Verify the company average (used in Review 1)
SELECT ROUND(AVG(salary), 2) AS company_avg
FROM   employees;

-- Verify the count of distinct departments (used in Review 2)
SELECT COUNT(DISTINCT department_id) AS distinct_depts_with_employees
FROM   employees
WHERE  department_id IS NOT NULL;



-- ##################################################################
-- ## SUMMARY OF ERROR CODES TO REMEMBER
-- ##################################################################

/*
   ORA-00934: group function is not allowed here
              -> You used AVG/SUM/COUNT/MAX/MIN in WHERE
              -> Move it into a scalar subquery or use HAVING

   ORA-01427: single-row subquery returns more than one row
              -> You used =, <, >, <=, >= with a subquery that
                 returns more than one row
              -> Switch to IN, ANY, ALL, EXISTS, or use an aggregate

   ORA-00904: invalid identifier
              -> Typo in column name, or using an alias too early

   ORA-00979: not a GROUP BY expression
              -> Non-aggregate column in SELECT must appear in GROUP BY
*/
