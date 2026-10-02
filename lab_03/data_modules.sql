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
    parent_location_id integer,
    depth integer
)
as $$
    with recursive location_tree as (
            -- начало
            select sl.id, sl.name, sl.parent_location_id, 0 as depth
            from sc1.storage_location as sl
            where sl.id = p_location_id

            union all

            select child.id, child.name, child.parent_location_id, lt.depth + 1
            from sc1.storage_location as child
            join location_tree as lt on child.parent_location_id = lt.id
        )

    select id, name, parent_location_id, depth
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
language plpgslq
as $$
begin
    update sc1.arrival_item
    set unit_price = unit_price * (1 + p_percent / 100)
    where product_id = p_product_id;
end;
$$;












