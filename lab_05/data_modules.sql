-- Лабораторная работа № 4. PostgreSQL + Python (PL/Python).
-- Перед запуском выполнить setup.sql в базе warehouse.

-- 1. Скалярная функция: стоимость одной позиции поступления

create or replace function sc1.get_total_price_py(p_price numeric, p_quantity integer)
returns numeric
as $$
return p_price * p_quantity
$$ language plpython3u immutable strict;


create or replace function sc1.get_total_price_py(p_price numeric, p_quantity integer)
returns numeric
as $$
return p_price * p_quantity;
$$ language plpython3u;


-- 2. Пользовательский агрегат: общая стоимость нескольких позиций
-- p_sum хранит сумму, накопленную при обработке предыдущих строк.

create or replace function sc1.arrival_sum_step_py(
    p_sum numeric, p_price numeric, p_quantity integer
)
returns numeric
as $$
if p_price is None or p_quantity is None:
    return p_sum

return p_sum + p_price * p_quantity
$$ language plpython3u immutable;

create or replace aggregate sc1.total_arrival_sum_py(numeric, integer) (
    sfunc = sc1.arrival_sum_step_py,
    stype = numeric,
    initcond = '0'
);



create or replace function sc1.arrival_sum_step_py(p_sum numeric, p_price numeric, p_quantity integer)
returns numeric
as $$
    if p_price = None or p_quantity = None
        return p_sum
    return p_sum + p_price * p_quantity
$$ language plpython3u immutable;

create or replace aggregate sc1.total_arrival_sum_py(numeric, integer)
(
    sfunc = sc1.arrival_sum_step_py,
    stype = numeric,
    initcond = '0'
);


-- 3. Табличная функция: все позиции поступления выбранного товара

create or replace function sc1.get_arrivals_by_product_py(p_product_id integer)
returns table (
    arrival_item_id integer,
    quantity integer,
    unit_price numeric
)
as $$
plan = plpy.prepare("""
    select ai.id as arrival_item_id, ai.quantity, ai.unit_price
    from sc1.arrival_item as ai
    where ai.product_id = $1
    order by ai.id
""", ["integer"])

return plpy.execute(plan, [p_product_id])
$$ language plpython3u stable strict;


create or replace function sc1.get_arrivals_by_product_py(p_product_id integer)
returns table (
    arrival_item_id integer,
    quantity integer,
    unit_price numeric
)
as $$
query = "select ai.id as arrival_item_id, ai.quantity, ai.unit_price from sc1.arrival_item as ai where ai.product_id = $1 order by ai.id"

plan = plpy.prepare(query, ["integer"])

rows = plpy.execute(plan, [p_product_id])

$$ language plpython3u stable strict;


-- 4. Хранимая процедура: изменить цены поступлений товара на p_percent %

create or replace procedure sc1.increase_product_price_py(
    p_product_id integer, p_percent numeric
)
as $$
if p_product_id is None or p_percent is None:
    plpy.error("Товар и процент должны быть указаны", sqlstate="22004")

if not p_percent.is_finite() or p_percent <= -100:
    plpy.error("Процент должен быть конечным числом больше -100", sqlstate="22023")

plan = plpy.prepare("""
    update sc1.arrival_item
    set unit_price = unit_price * (1 + $2 / 100)
    where product_id = $1
""", ["integer", "numeric"])

result = plpy.execute(plan, [p_product_id, p_percent])
plpy.notice("Обновлено строк: " + str(result.nrows()))
$$ language plpython3u;


-- 5. Триггер: записать старую и новую цену в журнал

create table if not exists sc1.product_price_log_py (
    id bigint generated always as identity primary key,
    arrival_item_id integer not null,
    product_id integer not null,
    old_price numeric(10, 3) not null,
    new_price numeric(10, 3) not null,
    changed_at timestamp not null default current_timestamp
);

create or replace function sc1.log_increase_product_price_py()
returns trigger
as $$
old_row = TD["old"]
new_row = TD["new"]

plan = plpy.prepare("""
    insert into sc1.product_price_log_py(
        arrival_item_id, product_id, old_price, new_price
    )
    values ($1, $2, $3, $4)
""", ["integer", "integer", "numeric", "numeric"])

plpy.execute(plan, [new_row["id"], new_row["product_id"],
                    old_row["unit_price"], new_row["unit_price"]])
return None
$$ language plpython3u;

create or replace trigger increase_product_price_trigger_py
after update of unit_price on sc1.arrival_item
for each row
when (old.unit_price is distinct from new.unit_price)
execute function sc1.log_increase_product_price_py();


-- 6. Пользовательский составной тип: остаток товара
-- Тип задаётся средствами PostgreSQL, работа с ним реализована на Python.
-- Проверка нужна для повторного запуска: CREATE TYPE не имеет OR REPLACE.

do $$
begin
    if not exists (
        select 1 from pg_type as t
        join pg_namespace as n on n.oid = t.typnamespace
        where n.nspname = 'sc1' and t.typname = 'product_balance_py'
    ) then
        create type sc1.product_balance_py as (
            product_id integer,
            arrived_quantity bigint,
            spent_quantity bigint,
            balance bigint
        );
    end if;
end;
$$;

create or replace function sc1.get_product_balance_py(p_product_id integer)
returns sc1.product_balance_py
as $$
plan = plpy.prepare("""
    select p.id,
        (select coalesce(sum(ai.quantity), 0)
         from sc1.arrival_item as ai
         where ai.product_id = p.id) as arrived_quantity,
        (select coalesce(sum(ei.quantity), 0)
         from sc1.expense_item as ei
         where ei.product_id = p.id) as spent_quantity
    from sc1.product as p
    where p.id = $1
""", ["integer"])

rows = plpy.execute(plan, [p_product_id])
if len(rows) == 0:
    return None

row = rows[0]
return {
    "product_id": row["id"],
    "arrived_quantity": row["arrived_quantity"],
    "spent_quantity": row["spent_quantity"],
    "balance": row["arrived_quantity"] - row["spent_quantity"]
}
$$ language plpython3u stable strict;


-- Экземпляр одной сущности

providers = []
for i in range(1, N_PROVIDERS + 1):
    name = f"Поставщик {i:03d}"[:20]
    phone = f"+7888{i:07d}"[:20]
    providers.append([i, name, phone])

create or replace function sc1.get_example_provider()
returns table (
    name varchar,
    phone varchar
)
as $$

name = f"Поставщик {:03d}"[:20]
phone = f"+7888{:07d}"[:20]

return {
    "name": name,
    "phone": phone
}
$$ language plpython3u;







