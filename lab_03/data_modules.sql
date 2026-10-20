-- Скалярная функция
create or replace function get_total_price(p_price numeric, p_quantity integer)
returns numeric
as $$
begin
    return p_price * p_quantity;
end;
$$ language plpgsql;

create or replace function get_total_price_on_id(p_id integer)
returns numeric
as $$
declare v_total numeric;
begin
    select price * quantity
    into v_total
    from products
    where id = p_id;

    return v_total;
end;
$$ language plpgsql;


create or replace function sc1.get_product_arrival_sum(p_product_id integer)
returns numeric
as $$
declare v_sum numeric;
begin
    select sum(quantity * unit_price)
    into v_sum
    from sc1.arrival_item
    where product_id = p_product_id;

    return v_sum;
end;
$$ language plpgsql;

-- Подставляемая табличная функция

create or replace function sc1.get_arrivals_by_product(p_product_id integer)
returns table (
    arrival_item_id integer,
    quantity integer,
    unit_price numeric
)
as $$
    select ai.id, ai.quantity, ai.unit_price
    from sc1.arrival_item as ai
    where ai.product_id = p_product_id;
$$ language sql;

-- Многооператорная табличная функция

create or replace function sc1.get_product_stats(p_product_id integer)
returns table (
    stat_name text,
    stat_value text
)

as $$
declare
    name text;
    v_total_quantity numeric;
    v_total_sum numeric;
    v_avg_price numeric;
begin
    select ai.name
    into name
    from sc1.product as ai
    where p_product_id = ai.id;

    select coalesce(sum(ai.quantity), 0)
    into v_total_quantity
    from sc1.arrival_item as ai
    where ai.product_id = p_product_id;

    select coalesce(sum(ai.quantity * ai.unit_price), 0)
    into v_total_sum
    from sc1.arrival_item as ai
    where ai.product_id = p_product_id;

    select coalesce(avg(ai.unit_price), 0)
    into v_avg_price
    from sc1.arrival_item as ai
    where ai.product_id = p_product_id;

    return query
    select 'name'::text, name;

    return query
    select 'total_quantity'::text, v_total_quantity::text;

    return query
    select 'total_sum'::text, v_total_sum::text;

    return query
    select 'avg_price'::text, v_avg_price::text;
end;
$$ language plpgsql;

-- рекурсивный запрос

create or replace function sc1.get_location_tree(p_location_id integer)
returns table (
    id integer,
    name varchar,
    capacity integer,
    parent_location_id integer,
    depth integer
)
as $$
    with recursive location_tree as (
            -- начало
            select sl.id, sl.name, sl.capacity, sl.parent_location_id, 0 as depth
            from sc1.storage_location as sl
            where sl.id = p_location_id

            union all

            select child.id, child.name, child.capacity, child.parent_location_id, lt.depth + 1
            from sc1.storage_location as child
            join location_tree as lt on child.parent_location_id = lt.id
        )

    select id, name, capacity, parent_location_id, depth
    from location_tree;
$$ language sql;

-- хранимая процедура

create or replace procedure sc1.reset_zero_prices()
language plpgsql
as $$
begin
    update sc1.arrival_item
    set unit_price = 1
    where unit_price = 0;
end;
$$;

create or replace procedure sc1.increase_product_price(p_product_id integer, p_percent numeric)
language plpgsql
as $$
begin
    update sc1.arrival_item
    set unit_price = unit_price * (1 + p_percent / 100)
    where product_id = p_product_id;
end;
$$;

-- рекурсивная процедура

create or replace procedure sc1.increase_storage_capacity(p_storage_location_id integer, p_percent numeric)
language plpgsql
as $$
begin
    with recursive location_tree as (
        select sl.id
        from sc1.storage_location as sl
        where sl.id = p_storage_location_id

        union all

        select child.id
        from sc1.storage_location as child
        join location_tree as lt on child.parent_location_id = lt.id
    )

    update sc1.storage_location
    set capacity = capacity * (1 + p_percent / 100)
    where id in (select id from location_tree);
end;
$$;

-- процедура с курсором

create or replace procedure sc1.increase_product_prices_cursor(p_product_id integer, p_percent numeric)
language plpgsql
as $$
declare
    rec record;
    cur cursor for
        select id, unit_price
        from sc1.arrival_item 
        where product_id = p_product_id;
begin
    for rec in cur loop
        update sc1.arrival_item
        set unit_price = unit_price * (1 + p_percent / 100)
        where id = rec.id;
    end loop;
end;
$$;

-- процедура с метаданными

create or replace procedure sc1.show_table_columns(p_table_name text)
language plpgsql
as $$
declare
    v_info text;
begin
    select string_agg(column_name || ':' || data_type, E'\n' order by ordinal_position)
    into v_info from information_schema.columns where table_schema = 'sc1' and table_name = p_table_name;

    raise notice e'%\n%', p_table_name, v_info;
end;
$$;

-- триггер after

create or replace function sc1.log_increase_product_price()
returns trigger
as $$
begin
    raise notice 'Увеличена цена продукта % была % стала %', new.product_id, old.unit_price, new.unit_price;

    return new;
end;
$$ language plpgsql;

create or replace trigger increase_product_price_trigger
after update of unit_price on sc1.arrival_item for each row execute function sc1.log_increase_product_price();


-- триггер instead of

create or replace view sc1.product_view as 
select id, name, unit, description from sc1.product;

create or replace function sc1.product_view_insert()
returns trigger
as $$
begin
    insert into sc1.product(id, name, unit, description)
    values(new.id, new.name, new.unit, new.description);

    return new;
end;
$$ language plpgsql;

create or replace trigger product_view_insert_trigger
instead of insert on sc1.product_view for each row execute function sc1.product_view_insert();


-- insert into sc1.product_view(id, name, unit, description) values(100, 'test pr', 100, 'test');



------------------------------------------------------------------

create or replace function get_arrival_by_product_id(p_product_id integer)
returns table(product_name varchar, arrival_id integer, quantity integer, unit_price numeric, total_price numeric)
as $$
begin
    return query
    select p.name, ai.id, ai.quantity, ai.unit_price, ai.unit_price * ai.quantity
    from sc1.arrival_item as ai
    join sc1.product as p on ai.product_id = p.id
    where ai.product_id = p_product_id;
end;
$$ language plpgsql;

create or replace function get_arrival_by_product_id(p_product_id integer)
returns table(product_name varchar, arrival_id integer, quantity integer, unit_price numeric, total_price numeric)
as $$
begin
    return query
    select p.name, ai.id, ai.quantity, ai.unit_price, ai.unit_price * ai.quantity
    from sc1.arrival_item as ai, sc1.product as p
    where ai.product_id = p.id and p.id = p_product_id;
end;
$$ language plpgsql;






create or replace function sc1.get_product_storage(p_product_id integer)
returns table(product_name varchar, storage_name varchar, location_type varchar, actual_quantity integer, employee_name varchar)
as $$
begin
    return query
    select p.name, sl.name, sl.location_type, i.actual_quantity, e.full_name
    from sc1.inventory as i
    join sc1.product as p on i.product_id = p.id
    join sc1.storage_location as sl on i.storage_location_id = sl.id
    join sc1.employee as e on i.employee_id = e.id
    where i.product_id = p_product_id;
end;
$$ language plpgsql;

create or replace function sc1.get_arrival_info(p_arrival_id integer)
returns table(arrival_id integer, name varchar, quantity integer, unit_price numeric, sl_name varchar)
as $$
begin
    return query
    select ai.id, p.name, ai.quantity, ai.unit_price, sl.name from sc1.arrival_item ai join sc1.product p on ai.product_id = p.id join sc1.inventory i on i.product_id = p.id join sc1.storage_location sl on i.storage_location_id = sl.id where ai.id = p_arrival_id;
end;
$$ language plpgsql;






 




















































-- тригер при селекте таблицы будет выдавать заметку что она рассмотрена

create or replace function sc1.log_select_on_table()
returns trigger
as $$
begin
    raise notice 'Таблица была рассмотрена %', informatioon_schema.table_name;
end;
$$ language plpgsql;

create or replace trigger notice_select
after select on sc1.* for each row execute function sc1.log_select_on_table();


-- изменения

update sc1.product set description = (select 'Приходил ' || count(*) || 'раз' from sc1.arrival_item where product_id = sc1.product.id) where id in (select product_id from sc1.arrival_item);

update sc1.product p set description = 'Приходил ' || a.cnt || 'раз' from (select product_id, count(*) as cnt from sc1.arrival_item group by product_id) a where p.id = a.product_id;

update sc1.arrival_item ai set ai.unit_price = ai.unit_price * 1.1 from sc1.product p where p.id = ai.product_id and p.unit = 'кг';

insert into sc1.product select ai.product_id + 10000, 'Товар ' || ai.product_id, 'шт', 'AUTO- ' || ai.product_id, 'Добавлено автоматически' from sc1.arrival_item ai where not exists (select 1 from sc1.product p where p.id = ai.product_id);

pdate sc1.product p set description = case when (select count(*) from sc1.arrival_item ai where p.id = ai.product_id) = 0 then 'Ни разу не приходил' else 'Приходил ' || (select count(*) from sc1.arrival_item ai where p.id = ai.product_id) || 'раз';


delete sc1.product where description = 'автоматически' and not exists (select 1 from sc1.arrival_item ai where id = ai.product_id);

insert into sc1.employee values (1001, 'Петров Пётр', '+7-999-999-99-99', 'Грузчик') returning id, full_name;

update sc1.inventory i set actual_quantity = (select coalesce(sum(ai.quantity), 0) from sc1.arrival_item ai where ai.product_id = i.product_id); 

alter table sc1.product add column quantity integer; 
alter table sc1.product drop column quantity;
update sc1.product p set quantity = (select coalesce(sum(quantity), 0) from sc1.arrival_item ai where p.id = ai.product_id);

create table sc1.product_new as select ai.product_id, sum(ai.quantity) as quantity from sc1.arrival_item ai group by ai.product_id;

select p.product_id, p.quantity, coalesce(sum(ai.quantity), 0) as quantity from sc1.product_new p left join sc1.arrival_item ai on ai.product_id =  p.product_id group by p.product_id, p.quantity;


create table sc1.category(id integer primary key, name varchar(50) not null);

create table sc1.supplier(id serial primaty_key, name varchar(100) not null, phone varchar(100), email varchar(100) unique, is_active boolean default true, created_at timestamp default now());

alter table sc1.product add column category_id integer;

alter table sc1.product add constraint fk_product_category foreign key (category_id) references sc1.category(id);


-- view

create view sc1.v_product_arrival as select p.name, ai.quantity, ai.unit_price from sc1.arrival_item ai join sc1.product p on p.id = ai.product_id;

create or replace view sc1.v_product_total as select p.id, p.name, coalesce(sum(ai.quantity), 0) as total from sc1.product p left join sc1.arrival_item ai on p.id = ai.product_id group by p.id, p.name;
 
-- index

create index idx_product_name on sc1.product(name);

-- оконные функции

func() over (partition by col1, col2 order by col3 rows between ... and ...)

select product_id, quantity, sum(quantity) over (partition by product_id) as total from sc1.arrival_item;

select product_id, quantity, sum(quantity) over (partition by product_id) from sc1.arrival_item;

select data, sum(amount) over (order by data) as total from sc1.arrival;

select p.name, ai.unit_price, case when ai.unit_price < 100 then 'дешевый' when ai.unit_price < 500 then 'Sredni'
when ai.unit_price > 500 then 'dorigoi' end as category from sc1.product p join sc1.arrival_item ai on p.id = ai.product_id;

select e.full_name, coalesce(e.phone, 'не указан') from sc1.employee e; 

ALTER TABLE sc1.employee
ALTER COLUMN phone DROP NOT NULL;

insert into sc1.employee select id + 10000, full_name || 'NEW', null, null from sc1.employee where id < 15;

select name, unit, case when unit = 'кг' then 'Вес' when unit = 'г' then 'Вес' when unit = 'шт' then 'Кол-во' end as category from sc1.product;

select name, unit, case when unit = 'кг' then 'Вес' when unit = 'г' then 'Вес' when unit = 'шт' then 'Кол-во' end as category from sc1.product order by category ;

create view sc1.v_product_with_category as select name, unit, case when unit = 'кг' then 'Вес' when unit = 'г' then 'Вес' when unit = 'шт' then 'Кол-во' end as category
from sc1.product;

select from where group by having order by limit

select case when unit in ('кг', 'г') then 'Вес' else 'Штучный' end as type, count(*) cnt from sc1.product group by case when unit in ('кг', 'г') then 'Вес' else 'Штучный' end;


create or replace function sc1.get_price(p_product_id integer)
returns table (price integer)
language plpgsql
as $$
begin

    return sc1.product.id;

end;
$$;

create or replace function get_storage_location_tree(p_id integer)
returns table (id integer, name varchar, capacity integer, p_id integer)
with recursive location_tree as (
    select sl.id, sl.name, sl.capacity, sl.parent_location_id, 0 as depth from sc1.storage_location sl where p_id = sl.id

    union all

    select child.id, child.name, child.capacity, child.parent_location_id, lt.depth + 1 from sc1.storage_location child join location_tree lt on child.parent_location_id = lt.id
)
select * from location_tree


create or replace procedure sc1.increase_product_prices(p_product_id integer)
as $$
declare
    rec record;

    cur cursor for select id, unit_price from sc1.arrival_item where id = p_product_id;
begin
    for rec in cur loop 
        update sc1.arrival_item set unit_price = unit_price * 1.2 where id = rec.id;
    end loop;

end;
$$ langeage plpgsql;

create or replace procedure sc1.increase_product_prices(p_product_id integer)
as $$
declare
    rec record;

    cur cursor for select id, unit_price from sc1.arrival_item where id = p_product_id;
begin
    open cur;

    loop fetch cur into rec;
        exit when not found;
        update sc1.arrival_item set unit_price = unit_price * 1.2 where id = rec.id;
    end loop;

    close cur;

end;
$$ langeage plpgsql;

do $$
declare i integer;
begin
for i in 1..5 loop
    raise notice 'i = %', i;
end loop;
end;
$$ language plpgsql;


do $$
    declare rec record;
    begin
        for rec in select id, unit_price from sc1.arrival_item loop
            raise notice 'id =% unit_price =%', rec.id, rec.unit_price;
        end loop;
    end;
$$ language plpgsql;

do $$
    declare rec record;
    cur cursor for select id, unit_price from sc1.arrival_item;
    begin
        for rec in cur loop
            raise notice 'id =% unit_price =%', rec.id, rec.unit_price;
        end loop;
    end;
$$ language plpgsql;


3. ОСНОВНЫЕ ПРЕДСТАВЛЕНИЯ information_schema

information_schema.schemata
    Список схем базы данных.

information_schema.tables
    Информация о таблицах и представлениях.

information_schema.columns
    Столбцы таблиц и представлений:
    имена, типы данных, NULL, DEFAULT и т. д.

information_schema.table_constraints
    Ограничения таблиц:
    PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK.

information_schema.key_column_usage
    Столбцы, участвующие в ограничениях
    PRIMARY KEY, FOREIGN KEY, UNIQUE.

information_schema.constraint_column_usage
    Столбцы, используемые некоторыми ограничениями.

information_schema.referential_constraints
    Информация об ограничениях внешнего ключа,
    включая правила ON UPDATE и ON DELETE.

information_schema.views
    Информация о представлениях (VIEW).

information_schema.routines
    Функции и процедуры.

information_schema.parameters
    Параметры функций и процедур.

information_schema.triggers
    Информация о триггерах.

information_schema.sequences
    Информация о последовательностях.

information_schema.table_privileges
    Права доступа к таблицам.

information_schema.column_privileges
    Права доступа к отдельным столбцам.




    -- триггеры
create or replace function sc1.log_trigger()
returns trigger
as $$
begin
    raise notice 'Цена изменена old = %, new = %', old.unit_price, new.unit_price;

    return new;
end;
$$ language plpgsql;

create or replace trigger update_unit_price_in_arrival_item after update of unit_price on sc1.arrival_item for each row execute function sc1.log_trigger();

CREATE [OR REPLACE] TRIGGER имя_триггера
BEFORE | AFTER | INSTEAD OF
INSERT | UPDATE | DELETE | TRUNCATE
ON имя_таблицы
FOR EACH ROW | FOR EACH STATEMENT
WHEN (условие)
EXECUTE FUNCTION имя_функции();


create or replace function sc1.zapret()
returns trigger
as $$
begin
    raise notice 'НЕЛЬЗЯ МЕНЯТЬ ЦЕНУ';

    return old;
end;
$$ language plpgsql;

create or replace trigger zapret_trigger before update of unit_price on sc1.arrival_item for each row execute function sc1.zapret();

create or replace view sc1.v_arrival_item as (select p.name as product_name, ai.id as arrival_item_id, ai.unit_price as unit_price from sc1.product p join sc1.arrival_item ai on p.id = ai.product_id);

create or replace function sc1.update_price_view_log()
returns trigger
as $$
begin
    update sc1.arrival_item set unit_price = new.unit_price;
    raise notice 'Цена изменена через view old = % new = %', old.unit_price, new.unit_price;

    return new;
end;
$$ language plpgsql;

create trigger update_unit_on_view instead of update on sc1.v_arrival_item for each row execute function sc1.update_price_view_log();

create or replace function sc1.get_item_total(p_arrival_item_id integer)
returns numeric
as $$
declare total_sum numeric;
begin
    select coalesce(unit_price * quantity, 0) into total_sum from sc1.arrival_item where id = p_arrival_item_id;

    return total_sum;
end;
$$ language plpgsql;


create or replace function sc1.get_arrival_count(p_product_id integer)
returns numeric
as $$
declare cnt integer;
begin

    select count(*) into cnt from sc1.arrival_item where product_id = p_product_id; 

    return cnt;
end;
$$ language plpgsql;


select or replace function sc1.get_arrivals_by_period(p_product_id integer, p_from timestamp, p_to timestamp)
returns table(arrival_item_id integer, p_name varchar, )





функция по массиву товаров находит сотрудника который имел опыт с товарами


create or replace function sc1.find_employee_with_prod(p_product_id integer)
returns table (
    full_name varchar, product_id integer)
as $$
begin
    return query
    select e.full_name, p_product_id from sc1.inventory i join sc1.employee e on e.id = i.employee_id where i.product_id = p_product_id;

end;
$$ language plpgsql;



