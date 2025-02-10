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
