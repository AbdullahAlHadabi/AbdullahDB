-- COMPANY SQL Developer Task
-- Database Joins and Complex Queries

DESC EMPLOYEE;
DESC DEPARTMENT;
DESC PROJECT;
DESC DEPENDENT;
DESC WORKS_ON;

-- Query 1: Employee Projects Report
SELECT e.fname || ' ' || e.lname    AS "Employee",
       e.ssn                        AS "SSN",
       d.dname                      AS "Department",
       p.pname                      AS "Project",
       w.hours                      AS "Hours Worked"
FROM   employee   e
JOIN   department d  ON e.dno      = d.dnum
JOIN   works_on   w  ON e.ssn      = w.essn
JOIN   project    p  ON w.pno      = p.pnumber
ORDER BY d.dname, e.lname, p.pname;

-- Query 2: Employee Dependents Report
SELECT e.fname || ' ' || e.lname        AS "Employee",
       e.ssn                            AS "SSN",
       d.dname                          AS "Department",
       NVL(dep.dependent_name, 'None')  AS "Dependent Name",
       NVL(dep.relationship, 'N/A')     AS "Relationship"
FROM   employee   e
JOIN   department d   ON e.dno  = d.dnum
LEFT JOIN dependent dep ON e.ssn = dep.essn
ORDER BY e.lname, dep.dependent_name;

-- Query 3: Projects with Right Join Analysis
SELECT e.fname || ' ' || e.lname        AS "Employee",
       NVL(e.ssn, 'No Employee')        AS "SSN",
       d.dname                          AS "Department",
       p.pname                          AS "Project",
       p.pnumber                        AS "Project No",
       w.hours                          AS "Hours"
FROM   employee   e
RIGHT JOIN works_on   w  ON e.ssn      = w.essn
RIGHT JOIN project    p  ON w.pno      = p.pnumber
JOIN       department d  ON p.dno      = d.dnum
ORDER BY p.pname, e.lname;

-- Query 4: Employee and Supervisor Relationship
SELECT emp.fname || ' ' || emp.lname   AS "Employee",
       emp.ssn                         AS "Employee SSN",
       sup.fname || ' ' || sup.lname   AS "Supervisor",
       sup.ssn                         AS "Supervisor SSN",
       d.dname                         AS "Department"
FROM   employee   emp
JOIN   employee   sup ON emp.super_ssn = sup.ssn
JOIN   department d   ON emp.dno       = d.dnum
ORDER BY d.dname, emp.lname;

