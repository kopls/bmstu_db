create database warehouse;
\connect warehouse
create schema sc1;

create table sc1.product(
    id integer,
    name varchar(20),
    unit varchar(10),
    article varchar (20),
    description text
);

create table sc1.employee(
    id integer,
    full_name varchar(30),
    phone varchar(20),
    job_title varchar (30)
);

create table sc1.arrival(
    id integer,
    arrival_time timestamp,
    provider_id integer,
    invoice_num varchar(30),
    responsible_employee varchar(30)
);

create table sc1.expense(
    id integer,
    expense_time timestamp,
    recipient varchar(30),
    basis text,
    responsible_employee varchar(30)
);

create table sc1.arrival_item(
    id integer,
    arrival_id integer,
    product_id integer,
    quantity integer,
    unit_price numeric(10, 3)
);

create table sc1.expense_item(
    id integer,
    expense_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    note TEXT
);

create table sc1.expense_distribution(
    id integer,
    arrival_item_id INTEGER,
    expense_item_id INTEGER,
    quantity INTEGER,
    note TEXT
);

create table sc1.storage_location(
    id integer,
    name VARCHAR(30),
    location_type VARCHAR(20),
    capacity INTEGER,
    parent_location_id INTEGER
);

create table sc1.inventory(
    id integer,
    product_id INTEGER,
    storage_location_id INTEGER,
    employee_id INTEGER,
    actual_quantity INTEGER
);

create schema sc2;
create table sc2.provider(
    id integer,
    name varchar(20),
    phone varchar (20)
);
