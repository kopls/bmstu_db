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





create or replace function sc1.get_arrival_info(p_arrival_id integer)
returns table(arrival_id integer, name varchar, quantity integer, unit_price numeric, sl_name varchar)
as $$
begin
    return query
    select ai.id, p.name, ai.quantity, ai.unit_price, sl.name
    from sc1.arrival_item as ai
    join sc1.product as p on ai.product_id = p.id
    join sc1.inventory as i on ai.product_id = i.product_id
    join sc1.storage_location as sl on i.storage_location_id = sl.id
    where ai.id = p_arrival_id;
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
        update sc1.arrival_item
        set unit_price = unit_price * (1 + p_percent / 100)
end;
$$ language plpgsql;


