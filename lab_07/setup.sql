-- Табличная функция из lab_03/data_modules.sql.
create or replace function sc1.get_arrivals_by_product(p_product_id integer)
returns table (arrival_item_id integer, quantity integer, unit_price numeric)
as $$
    select ai.id, ai.quantity, ai.unit_price
    from sc1.arrival_item ai
    where ai.product_id = p_product_id;
$$ language sql;

-- Процедура возвращает строки одним JSON-массивом через выходной параметр.
create or replace procedure sc1.get_arrivals_for_lab07(
    in p_product_id integer,
    inout rows_json jsonb default null
)
language plpgsql
as $$
begin
    select coalesce(jsonb_agg(to_jsonb(t) order by t.arrival_item_id), '[]'::jsonb)
    into rows_json
    from sc1.get_arrivals_by_product(p_product_id) t;
end;
$$;
