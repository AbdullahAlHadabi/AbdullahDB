-- ============================================
-- Bookstore Database — Oracle Version
-- Author: Abdullah Al Hadabi
-- Database: Oracle 19c
-- ============================================

-- Step 1: Clean up if tables already exist
BEGIN EXECUTE IMMEDIATE 'DROP TABLE ORDERS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE BOOKS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE AUTHORS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Step 2: Create AUTHORS table
CREATE TABLE AUTHORS (
    author_id   NUMBER          PRIMARY KEY,
    first_name  VARCHAR2(50)    NOT NULL,
    last_name   VARCHAR2(50)    NOT NULL,
    country     VARCHAR2(50),
    birth_year  NUMBER(4)
);

-- Step 3: Create BOOKS table
CREATE TABLE BOOKS (
    book_id     NUMBER          PRIMARY KEY,
    title       VARCHAR2(200)   NOT NULL,
    author_id   NUMBER          NOT NULL,
    price       NUMBER(8,2)     NOT NULL,
    genre       VARCHAR2(50),
    publish_year NUMBER(4),
    CONSTRAINT fk_book_author FOREIGN KEY (author_id) REFERENCES AUTHORS(author_id)
);

-- Step 4: Create ORDERS table
CREATE TABLE ORDERS (
    order_id        NUMBER          PRIMARY KEY,
    book_id         NUMBER          NOT NULL,
    customer_name   VARCHAR2(100)   NOT NULL,
    quantity        NUMBER(3)       NOT NULL,
    order_date      DATE            DEFAULT SYSDATE,
    total_price     NUMBER(10,2),
    CONSTRAINT fk_order_book FOREIGN KEY (book_id) REFERENCES BOOKS(book_id)
);

-- Step 5: Insert AUTHORS data
INSERT INTO AUTHORS VALUES (1, 'George',    'Orwell',      'UK',      1903);
INSERT INTO AUTHORS VALUES (2, 'J.K.',      'Rowling',     'UK',      1965);
INSERT INTO AUTHORS VALUES (3, 'Paulo',     'Coelho',      'Brazil',  1947);
INSERT INTO AUTHORS VALUES (4, 'Haruki',    'Murakami',    'Japan',   1949);
INSERT INTO AUTHORS VALUES (5, 'Agatha',    'Christie',    'UK',      1890);

-- Step 6: Insert BOOKS data
INSERT INTO BOOKS VALUES (1, '1984',                        1, 12.99, 'Dystopia',  1949);
INSERT INTO BOOKS VALUES (2, 'Animal Farm',                 1,  9.99, 'Satire',    1945);
INSERT INTO BOOKS VALUES (3, 'Harry Potter and the Sorcerer''s Stone', 2, 19.99, 'Fantasy', 1997);
INSERT INTO BOOKS VALUES (4, 'The Alchemist',               3, 14.99, 'Fiction',   1988);
INSERT INTO BOOKS VALUES (5, 'Norwegian Wood',              4, 13.99, 'Romance',   1987);
INSERT INTO BOOKS VALUES (6, 'Murder on the Orient Express',5, 11.99, 'Mystery',   1934);

-- Step 7: Insert ORDERS data
INSERT INTO ORDERS VALUES (1, 1, 'Abdullah Al Hadabi', 2, DATE '2026-01-15', 25.98);
INSERT INTO ORDERS VALUES (2, 3, 'Sara Ahmed',         1, DATE '2026-01-20', 19.99);
INSERT INTO ORDERS VALUES (3, 4, 'Mohammed Ali',       3, DATE '2026-02-05', 44.97);
INSERT INTO ORDERS VALUES (4, 2, 'Fatma Hassan',       1, DATE '2026-02-10',  9.99);
INSERT INTO ORDERS VALUES (5, 6, 'Abdullah Al Hadabi', 2, DATE '2026-03-01', 23.98);
INSERT INTO ORDERS VALUES (6, 5, 'Ahmed Salem',        1, DATE '2026-03-15', 13.99);

-- Step 8: Commit all data
COMMIT;

-- Step 9: Verify everything
SELECT 'AUTHORS' AS table_name, COUNT(*) AS total FROM AUTHORS  UNION ALL
SELECT 'BOOKS',                  COUNT(*)           FROM BOOKS    UNION ALL
SELECT 'ORDERS',                 COUNT(*)           FROM ORDERS;