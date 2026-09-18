alter table sc1.product
add constraint pk_product
primary key(id);

alter table sc1.employee
add constraint pk_employee
primary key(id);

alter table sc1.arrival
add constraint pk_arrival
primary key (id);

alter table sc1.expense
add constraint pk_expense
primary key (id);

alter table sc1.arrival_item
add constraint pk_arrival_item
primary key (id);

alter table sc1.expense_item
add constraint pk_expense_item
primary key (id);

alter table sc1.expense_distribution
add constraint pk_expense_distribution
primary key (id);

alter table sc1.storage_location
add constraint pk_storage_location
primary key (id);

alter table sc1.inventory
add constraint pk_inventory
primary key (id);

alter table sc2.provider
add constraint pk_provider
primary key (id);
 

alter table sc1.product
alter column name set not null;

alter table sc1.product
alter column unit set not null; 

alter table sc1.product
alter column article set not null;

alter table sc1.employee
alter column full_name set not null;

alter table sc1.employee
alter column phone set not null;

alter table sc1.employee
alter column job_title set not null;

alter table sc1.arrival
alter column arrival_time set not null;

alter table sc1.arrival
alter column provider_id set not null;

alter table sc1.arrival
alter column invoice_num set not null;

alter table sc1.arrival
alter column responsible_employee set not null;

alter table sc1.expense
alter column expense_time set not null;

alter table sc1.expense
alter column recipient set not null;

alter table sc1.expense
alter column basis set not null;

alter table sc1.expense
alter column responsible_employee set not null;

alter table sc1.arrival_item
alter column arrival_id set not null;

alter table sc1.arrival_item
alter column product_id set not null;

alter table sc1.arrival_item
alter column quantity set not null;

alter table sc1.arrival_item
alter column unit_price set not null;

alter table sc1.expense_item
alter column expense_id set not null;

alter table sc1.expense_item
alter column product_id set not null;

alter table sc1.expense_item
alter column quantity set not null;

alter table sc1.expense_distribution
alter column arrival_item_id set not null;

alter table sc1.expense_distribution
alter column expense_item_id set not null;

alter table sc1.expense_distribution
alter column quantity set not null;

alter table sc1.storage_location
alter column name set not null;

alter table sc1.storage_location
alter column location_type set not null;

alter table sc1.storage_location
alter column capacity set not null;

alter table sc1.inventory
alter column product_id set not null;

alter table sc1.inventory
alter column storage_location_id set not null;

alter table sc1.inventory
alter column employee_id set not null;

alter table sc1.inventory
alter column actual_quantity set not null;

alter table sc2.provider
alter column name set not null;

alter table sc2.provider
alter column phone set not null;

alter table sc1.product
add constraint uq_product_article
unique(article);

alter table sc1.employee
add constraint uq_employee_phone
unique(phone);

 alter table sc2.provider
add constraint uq_provider_phone
unique(phone);

alter table sc1.arrival_item
add constraint chk_arrival_item_quantity
check(quantity > 0);

alter table sc1.arrival_item
add constraint chk_arrival_item_unit_price
check(unit_price > 0);

alter table sc1.expense_item
add constraint chk_expense_item_quantity
check(quantity > 0);

alter table sc1.expense_distribution
add constraint chk_expense_distribution_quantity
check (quantity > 0);

alter table sc1.storage_location
add constraint chk_storage_location_capacity
check (capacity > 0);

alter table sc1.inventory
add constraint chk_inventory_actual_quantity
check (actual_quantity >= 0);


alter table sc1.arrival_item
add constraint fk_arrival_item_arrival
foreign key (arrival_id)
references sc1.arrival (id);

alter table sc1.arrival_item
add constraint fk_arrival_item_product
foreign key (product_id)
references sc1.product (id);

alter table sc1.expense_item
add constraint fk_expense_item_expense
foreign key (expense_id)
references sc1.expense (id);

alter table sc1.expense_item
add constraint fk_expense_item_product
foreign key (product_id)
references sc1.product (id);

alter table sc1.expense_distribution
add constraint fk_expense_distribution_arrival_item
foreign key (arrival_item_id)
references sc1.arrival_item (id);

alter table sc1.expense_distribution
add constraint fk_expense_distribution_expense_item
foreign key (expense_item_id)
references sc1.expense_item (id);

alter table sc1.storage_location
add constraint fk_storage_location_parent
foreign key (parent_location_id)
references sc1.storage_location (id);

alter table sc1.inventory
add constraint fk_inventory_product
foreign key (product_id)
references sc1.product (id);

alter table sc1.inventory
add constraint fk_inventory_storage_location
foreign key (storage_location_id)
references sc1.storage_location (id);

alter table sc1.inventory
add constraint fk_inventory_employee
foreign key (employee_id)
references sc1.employee (id);

alter table sc1.arrival
add constraint fk_arrival_provider
foreign key (provider_id)
references sc2.provider (id);
