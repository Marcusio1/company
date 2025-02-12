-- Vytvorenie databázy a schémy
CREATE DATABASE IF NOT EXISTS COMPANY;
USE DATABASE COMPANY;

CREATE SCHEMA IF NOT EXISTS COMPANY_SCHEMA;
USE SCHEMA COMPANY_SCHEMA;

-- Zákazníci
CREATE TABLE IF NOT EXISTS staging_dim_customers (
    CustomerId INT PRIMARY KEY,
    CustomerName VARCHAR(100),
    ContactLastName VARCHAR(50),
    ContactFirstName VARCHAR(50),
    Phone VARCHAR(20),
    AddressLine1 VARCHAR(100),
    AddressLine2 VARCHAR(100),
    City VARCHAR(50),
    State VARCHAR(50),
    PostalCode VARCHAR(20),
    Country VARCHAR(50),
    SalesRepEmployeeNumber INT,
    CreditLimit DECIMAL(10,2)
);

-- Zamestnanci
CREATE TABLE IF NOT EXISTS staging_dim_employees (
    EmployeeNumber INT PRIMARY KEY,
    LastName VARCHAR(50),
    FirstName VARCHAR(50),
    Extension VARCHAR(10),
    Email VARCHAR(100),
    OfficeCode VARCHAR(10),
    ReportsTo INT,
    JobTitle VARCHAR(50)
);

-- Kancelárie
CREATE TABLE IF NOT EXISTS STAGING_DIM_OFFICES (
    officeCode INT PRIMARY KEY,
    city VARCHAR(50),
    phone VARCHAR(20),
    addressLine1 VARCHAR(100),
    addressLine2 VARCHAR(100),
    state VARCHAR(50),
    country VARCHAR(50),
    postalCode VARCHAR(20),
    territory VARCHAR(50)
);


-- Objednávky
CREATE TABLE IF NOT EXISTS staging_fact_orders (
    OrderNumber INT PRIMARY KEY,
    OrderDate DATE,
    RequiredDate DATE,
    ShippedDate DATE,
    Status VARCHAR(20),
    Comments TEXT,
    CustomerId INT,
    FOREIGN KEY (CustomerId) REFERENCES staging_dim_customers(CustomerId)
);

-- Detaily objednávok
CREATE TABLE IF NOT EXISTS staging_fact_orderdetails (
    OrderNumber INT,
    ProductCode VARCHAR(15),
    QuantityOrdered INT,
    PriceEach DECIMAL(10,2),
    OrderLineNumber INT,
    PRIMARY KEY (OrderNumber, ProductCode),
    FOREIGN KEY (OrderNumber) REFERENCES staging_fact_orders(OrderNumber),
    FOREIGN KEY (ProductCode) REFERENCES staging_dim_products(ProductCode)
);

-- Platby
CREATE TABLE IF NOT EXISTS staging_fact_payments (
    CustomerId INT,
    CheckNumber VARCHAR(50) PRIMARY KEY,
    PaymentDate DATE,
    Amount DECIMAL(10,2),
    FOREIGN KEY (CustomerId) REFERENCES staging_dim_customers(CustomerId)
);

-- Produktové línie
CREATE TABLE IF NOT EXISTS staging_dim_productlines (
    ProductLine VARCHAR(50) PRIMARY KEY,
    TextDescription VARCHAR(4000),
    HtmlDescription TEXT
);

-- Produkty
CREATE TABLE IF NOT EXISTS staging_dim_products (
    ProductCode VARCHAR(15) PRIMARY KEY,
    ProductName VARCHAR(100),
    ProductLine VARCHAR(50),
    ProductScale VARCHAR(10),
    ProductVendor VARCHAR(50),
    ProductDescription TEXT,
    QuantityInStock INT,
    BuyPrice DECIMAL(10,2),
    MSRP DECIMAL(10,2),
    FOREIGN KEY (ProductLine) REFERENCES staging_dim_productlines(ProductLine)
);

-- Načítanie údajov do staging tabuliek
CREATE OR REPLACE STAGE COMPANY_DATA;

COPY INTO staging_dim_customers
FROM @COMPANY_DATA/company_table_customers.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = ('NULL', ''));

COPY INTO staging_dim_employees
FROM @COMPANY_DATA/company_table_employees.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = ('NULL', ''));

COPY INTO staging_dim_offices
FROM @COMPANY_DATA/company_table_offices.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO staging_fact_orders
FROM @COMPANY_DATA/company_table_orders.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO staging_fact_orderdetails
FROM @COMPANY_DATA/company_table_orderdetails.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO staging_fact_payments
FROM @COMPANY_DATA/company_table_payments.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO staging_dim_productlines
FROM @COMPANY_DATA/company_table_productlines.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO staging_dim_products
FROM @COMPANY_DATA/company_table_products.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);


-- Dimenzia zákazníkov
CREATE OR REPLACE TABLE dim_customer AS
SELECT 
    CustomerId AS customer_id,
    CustomerName AS customer_name,
    CONCAT(ContactFirstName, ' ', ContactLastName) AS contact_name,
    Phone AS phone,
    CONCAT(AddressLine1, ' ', COALESCE(AddressLine2, '')) AS address,
    City AS city,
    State AS state,
    Country AS country,
    PostalCode AS postal_code,
    SalesRepEmployeeNumber AS sales_rep_id,
    CreditLimit AS credit_limit
FROM staging_dim_customers;

-- Dimenzia zamestnancov (predstavuje obchodných zástupcov)
CREATE OR REPLACE TABLE dim_employee AS
SELECT 
    e.EmployeeNumber AS employee_id,
    CONCAT(e.FirstName, ' ', e.LastName) AS full_name,
    e.JobTitle AS job_title,
    o.city AS office_city,
    o.country AS office_country,
    e.Email AS email
FROM staging_dim_employees e
LEFT JOIN staging_dim_offices o ON e.OfficeCode = o.officeCode;

-- Dimenzia produktov
CREATE OR REPLACE TABLE dim_product AS
SELECT 
    p.ProductCode AS product_code,
    p.ProductName AS product_name,
    p.ProductLine AS product_line,
    p.ProductScale AS product_scale,
    p.ProductVendor AS product_vendor,
    p.BuyPrice AS buy_price,
    p.MSRP AS msrp,
    p.QuantityInStock AS quantity_in_stock
FROM staging_dim_products p;

-- Dimenzia dátumu (spoločná pre objednávky a platby)
CREATE OR REPLACE TABLE dim_date AS
SELECT DISTINCT 
    OrderDate AS date,
    EXTRACT(DAY FROM OrderDate) AS day,
    EXTRACT(MONTH FROM OrderDate) AS month,
    EXTRACT(YEAR FROM OrderDate) AS year,
    EXTRACT(QUARTER FROM OrderDate) AS quarter
FROM staging_fact_orders
UNION
SELECT DISTINCT 
    PaymentDate AS date,
    EXTRACT(DAY FROM PaymentDate) AS day,
    EXTRACT(MONTH FROM PaymentDate) AS month,
    EXTRACT(YEAR FROM PaymentDate) AS year,
    EXTRACT(QUARTER FROM PaymentDate) AS quarter
FROM staging_fact_payments;

CREATE OR REPLACE TABLE fact_sales AS
SELECT 
    o.OrderNumber AS fact_id,
    d.date AS date_id,
    c.customer_id AS customer_id,
    e.employee_id AS employee_id,
    p.product_code AS product_code,
    od.QuantityOrdered AS quantity_ordered,
    od.PriceEach AS price_each,
    (od.QuantityOrdered * od.PriceEach) AS total_price,
    pay.payment_amount AS payment_amount
FROM staging_fact_orders o
LEFT JOIN staging_fact_orderdetails od ON o.OrderNumber = od.OrderNumber
LEFT JOIN dim_customer c ON o.CustomerId = c.customer_id
LEFT JOIN dim_employee e ON c.sales_rep_id = e.employee_id
LEFT JOIN dim_product p ON od.ProductCode = p.product_code
LEFT JOIN staging_fact_payments pay ON o.CustomerId = pay.CustomerId
LEFT JOIN dim_date d ON o.OrderDate = d.date;

-- Odstránenie staging tabuliek
DROP TABLE IF EXISTS staging_dim_customers;
DROP TABLE IF EXISTS staging_dim_employees;
DROP TABLE IF EXISTS staging_dim_offices;
DROP TABLE IF EXISTS staging_dim_productlines;
DROP TABLE IF EXISTS staging_dim_products;
DROP TABLE IF EXISTS staging_fact_orders;
DROP TABLE IF EXISTS staging_fact_orderdetails;
DROP TABLE IF EXISTS staging_fact_payments;

-- Odstránenie dimenzionálnych tabuliek
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_employee;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_date;

-- Odstránenie faktovej tabuľky
DROP TABLE IF EXISTS fact_sales;


