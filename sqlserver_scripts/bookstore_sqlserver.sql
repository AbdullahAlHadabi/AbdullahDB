-- ============================================
-- Bookstore Database — SQL Server Version
-- Author: Abdullah Al Hadabi
-- Database: SQL Server 2019
-- ============================================

-- Step 1: Create and use the database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'BookstoreDB')
    CREATE DATABASE BookstoreDB;
GO

USE BookstoreDB;
GO

-- Step 2: Clean up if tables already exist
IF OBJECT_ID('ORDERS',  'U') IS NOT NULL DROP TABLE ORDERS;
IF OBJECT_ID('BOOKS',   'U') IS NOT NULL DROP TABLE BOOKS;
IF OBJECT_ID('AUTHORS', 'U') IS NOT NULL DROP TABLE AUTHORS;
GO

-- Step 3: Create AUTHORS table
CREATE TABLE AUTHORS (
    author_id   INT             PRIMARY KEY,
    first_name  VARCHAR(50)     NOT NULL,
    last_name   VARCHAR(50)     NOT NULL,
    country     VARCHAR(50),
    birth_year  INT
);
GO

-- Step 4: Create BOOKS table
CREATE TABLE BOOKS (
    book_id         INT             PRIMARY KEY,
    title           VARCHAR(200)    NOT NULL,
    author_id       INT             NOT NULL,
    price           DECIMAL(8,2)    NOT NULL,
    genre           VARCHAR(50),
    publish_year    INT,
    CONSTRAINT fk_book_author FOREIGN KEY (author_id) REFERENCES AUTHORS(author_id)
);
GO

-- Step 5: Create ORDERS table
CREATE TABLE ORDERS (
    order_id        INT             PRIMARY KEY,
    book_id         INT             NOT NULL,
    customer_name   VARCHAR(100)    NOT NULL,
    quantity        INT             NOT NULL,
    order_date      DATE            DEFAULT GETDATE(),
    total_price     DECIMAL(10,2),
    CONSTRAINT fk_order_book FOREIGN KEY (book_id) REFERENCES BOOKS(book_id)
);
GO

-- Step 6: Insert AUTHORS data
INSERT INTO AUTHORS VALUES (1, 'George',  'Orwell',   'UK',     1903);
INSERT INTO AUTHORS VALUES (2, 'J.K.',    'Rowling',  'UK',     1965);
INSERT INTO AUTHORS VALUES (3, 'Paulo',   'Coelho',   'Brazil', 1947);
INSERT INTO AUTHORS VALUES (4, 'Haruki',  'Murakami', 'Japan',  1949);
INSERT INTO AUTHORS VALUES (5, 'Agatha',  'Christie', 'UK',     1890);
GO

-- Step 7: Insert BOOKS data
INSERT INTO BOOKS VALUES (1, '1984',                              1, 12.99, 'Dystopia', 1949);
INSERT INTO BOOKS VALUES (2, 'Animal Farm',                       1,  9.99, 'Satire',   1945);
INSERT INTO BOOKS VALUES (3, 'Harry Potter and the Sorcerer Stone',2,19.99, 'Fantasy',  1997);
INSERT INTO BOOKS VALUES (4, 'The Alchemist',                     3, 14.99, 'Fiction',  1988);
INSERT INTO BOOKS VALUES (5, 'Norwegian Wood',                    4, 13.99, 'Romance',  1987);
INSERT INTO BOOKS VALUES (6, 'Murder on the Orient Express',      5, 11.99, 'Mystery',  1934);
GO

-- Step 8: Insert ORDERS data
INSERT INTO ORDERS VALUES (1, 1, 'Abdullah Al Hadabi', 2, '2026-01-15', 25.98);
INSERT INTO ORDERS VALUES (2, 3, 'Sara Ahmed',         1, '2026-01-20', 19.99);
INSERT INTO ORDERS VALUES (3, 4, 'Mohammed Ali',       3, '2026-02-05', 44.97);
INSERT INTO ORDERS VALUES (4, 2, 'Fatma Hassan',       1, '2026-02-10',  9.99);
INSERT INTO ORDERS VALUES (5, 6, 'Abdullah Al Hadabi', 2, '2026-03-01', 23.98);
INSERT INTO ORDERS VALUES (6, 5, 'Ahmed Salem',        1, '2026-03-15', 13.99);
GO

-- Step 9: Verify everything
SELECT 'AUTHORS' AS table_name, COUNT(*) AS total FROM AUTHORS  UNION ALL
SELECT 'BOOKS',                  COUNT(*)           FROM BOOKS    UNION ALL
SELECT 'ORDERS',                 COUNT(*)           FROM ORDERS;
GO