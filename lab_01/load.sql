copy sc1.product (id, name, unit, article, description) from '/tmp/warehouse_data/product.csv'
with (format csv, header, delimiter ';');

copy sc1.employee (id, full_name, phone, job_title) from '/tmp/warehouse_data/employee.csv'
with (format csv, header, delimiter ';');

copy sc2.provider (id, name, phone) from '/tmp/warehouse_data/provider.csv'
with (format csv, header, delimiter ';');

copy sc1.arrival (id, arrival_time, provider_id, invoice_num, responsible_employee) from '/tmp/warehouse_data/arrival.csv'
with (format csv, header, delimiter ';');

copy sc1.expense (id, expense_time, recipient, basis, responsible_employee) from '/tmp/warehouse_data/expense.csv'
with (format csv, header, delimiter ';');

copy sc1.storage_location (id, name, location_type, capacity, parent_location_id) from '/tmp/warehouse_data/storage_location.csv'
with (format csv, header, delimiter ';');

copy sc1.arrival_item (id, arrival_id, product_id, quantity, unit_price) from '/tmp/warehouse_data/arrival_item.csv'
with (format csv, header, delimiter ';');

copy sc1.expense_item (id, expense_id, product_id, quantity, note) from '/tmp/warehouse_data/expense_item.csv'
with (format csv, header, delimiter ';');

copy sc1.expense_distribution (id, arrival_item_id, expense_item_id, quantity, note) from '/tmp/warehouse_data/expense_distribution.csv'
with (format csv, header, delimiter ';');

copy sc1.inventory (id, product_id, storage_location_id, employee_id, actual_quantity) from '/tmp/warehouse_data/inventory.csv'
with (format csv, header, delimiter ';');

