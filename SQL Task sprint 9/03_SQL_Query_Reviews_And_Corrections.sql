-- SQL Query Reviews and Corrections
-- This file contains incorrect queries and their corrections

-- ===================================
-- Query Review 1: Employee-Department Join
-- ===================================

-- INCORRECT:
-- SELECT e.first_name, e.last_name, d.department_name
-- FROM employees e
-- JOIN departments d
-- ON e.employee_id = d.department_id;

-- CORRECT:
SELECT e.first_name,
       e.last_name,
       d.department_name  AS "Department"
FROM   employees   e
JOIN   departments d ON e.department_id = d.department_id
ORDER BY d.department_name, e.last_name;

-- ===================================
-- Query Review 2: Employee-Job Join
-- ===================================

-- INCORRECT:
-- SELECT e.first_name, e.last_name, j.job_title
-- FROM employees e
-- JOIN jobs j
-- ON e.employee_id = j.job_id;

-- CORRECT:
SELECT e.first_name,
       e.last_name,
       j.job_title                        AS "Job Title",
       TO_CHAR(e.salary, '$999,999.00')   AS "Salary"
FROM   employees e
JOIN   jobs      j ON e.job_id = j.job_id
ORDER BY j.job_title, e.last_name;

-- ===================================
-- Query Review 3: Department Filtering
-- ===================================

-- ORIGINAL ISSUE:
-- SELECT e.first_name, d.department_name
-- FROM employees e
-- LEFT JOIN departments d
-- ON e.department_id = d.department_id
-- WHERE d.department_name = 'Sales';

-- CORRECTION 1: Show all employees, mark which ones are in Sales
SELECT e.first_name,
       e.last_name,
       NVL(d.department_name, 'No Department') AS "Department"
FROM   employees   e
LEFT JOIN departments d ON e.department_id = d.department_id
ORDER BY d.department_name NULLS LAST, e.last_name;

-- CORRECTION 2: Show only Sales department employees
SELECT e.first_name,
       e.last_name,
       d.department_name  AS "Department"
FROM   employees   e
JOIN   departments d ON e.department_id = d.department_id
WHERE  d.department_name = 'Sales'
ORDER BY e.last_name;

-- CORRECTION 3: Show all employees but mark which ones are in Sales
SELECT e.first_name,
       e.last_name,
       CASE WHEN d.department_name = 'Sales'
            THEN 'Sales'
            ELSE NVL(d.department_name, 'No Department')
       END AS "Department"
FROM   employees   e
LEFT JOIN departments d ON e.department_id = d.department_id
ORDER BY e.last_name;

-- ===================================
-- Query Review 4: Employee-Manager Join
-- ===================================

-- INCORRECT:
-- SELECT e.first_name, m.first_name AS manager_name
-- FROM employees e
-- JOIN employees m
-- ON e.employee_id = m.manager_id;

-- CORRECT:
SELECT e.first_name  || ' ' || e.last_name   AS "Employee",
       e.salary                              AS "Employee Salary",
       m.first_name  || ' ' || m.last_name   AS "Manager",
       d.department_name                     AS "Department"
FROM   employees e
JOIN   employees   m ON e.manager_id    = m.employee_id
JOIN   departments d ON e.department_id = d.department_id
ORDER BY d.department_name, m.last_name, e.last_name;

