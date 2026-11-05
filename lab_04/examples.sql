-- Выполняй по одному блоку, чтобы видеть результат каждого объекта.

-- 1. Одна стоимость: 50
select sc1.get_total_price_py(12.5, 4);

select id, product_id, quantity, unit_price,
       sc1.get_total_price_py(unit_price, quantity) as total_price
from sc1.arrival_item
order by id limit 10;

-- 2. Одна сумма на каждый товар
select product_id, sc1.total_arrival_sum_py(unit_price, quantity) as total_sum
from sc1.arrival_item
group by product_id
order by product_id;

-- Сравнение со встроенным агрегатом (при пустом наборе наш агрегат даёт 0)
select sc1.total_arrival_sum_py(unit_price, quantity), sum(unit_price * quantity)
from sc1.arrival_item;

-- 3. Все позиции поступления товара 1
select * from sc1.get_arrivals_by_product_py(1);

-- 4 и 5. Изменение цен и автоматическое ведение журнала
-- Выполни весь блок от BEGIN до ROLLBACK в одном подключении.
begin;

select id, unit_price from sc1.arrival_item where product_id = 1 order by id;
call sc1.increase_product_price_py(1, 10);
select id, unit_price from sc1.arrival_item where product_id = 1 order by id;
select * from sc1.product_price_log_py where product_id = 1 order by id;

rollback;

-- 6. Значение составного типа и его отдельные поля
select sc1.get_product_balance_py(1);
select * from sc1.get_product_balance_py(1);
select (sc1.get_product_balance_py(1)).balance;

-- Создать значение типа вручную
select row(1, 14, 3, 11)::sc1.product_balance_py;
