-- Выгрузка данных из таблиц в JSON

select jsonb_pretty(jsonb_agg(jsonb_build_object('id', id, 'name', name))) as product_json from sc1.product;


-- Создание таблицы из json

\copy (select jsonb_pretty(jsonb_agg(jsonb_build_object('id', id, 'name', name))) as product_json from sc1.product) to 'product.jsonb';

create table sc1.product_json_staging(json_data jsonb);

insert into sc1.product_json_staging(json_data) select jsonb_agg(jsonb_build_object('id', id, 'name', name)) from sc1.product where id < 6;

create table sc1.product_restored as select (item->>'id')::int as id, item->>'name' as name from sc1.product_json_staging, jsonb_array_elements(json_data) as item;


-- Создать таблицу с колонуой jsonb

alter table sc1.product add column details jsonb;

update sc1.product set details = '{"материал": "Сталь", "Покрытие": "Цинк"}'::jsonb where id = 1;

update sc1.product set details = '{"status":"active", "discount":0}'::jsonb where details is null;

create table sc1.product_with_json(id serial primary key, name text, details jsonb);

insert into sc1.product_with_json(name, details) values 
('Гвоздь', '{"материал": "Сталь", "вес_кг": 0.1}'),
('Шуруп', '{"материал": "Латунь", "длина_мм": 30}'),
('Проволока', '{"толщина_мм": 1.2, "покрытие": "Оцинковка"}');



select jsonb_set(details, '{характеристики, вес_кг}', 0,6) from sc1.product_with_json;


-- Операции с json объектом

insert into sc1.product_with_json(name, details) values
('Танк', '{
  "материал": "Сталь",
  "покрытие": "Цинк",
  "гарантия_мес": 12,
  "характеристики": {
      "вес_кг": 0.5,
      "длина_мм": 100
  },
  "теги": ["крепёж", "металл", "строительство"]
}'::jsonb);

-- 1. Фрагмент
select details -> 'характеристики' as fragment from sc1.product_with_json where id = 4;


-- 2. Значения конкретных узлов
select details ->> 'материал' as material, details -> 'характеристики' ->> 'вес_кг' as weight from sc1.product_with_json where id = 4;

select details ->> 'материал' as material, details #> '{характеристики, вес_кг}' from sc1.product_with_json where id = 4;

-- 3. Проверка существования узла или атрибутаб
select details ? 'материал' as has_material, details ? 'скидка' as discount from sc1.product_with_json where id = 4;

-- 4. Изменение json
update sc1.product_with_json set details = details || '{"скидка":10}'::jsonb where id = 4;

-- 5. Разделить json 

select p.id, p.name, tag as тег from sc1.product_with_json p, jsonb_array_elements_text(p.details -> 'теги') as tag where id = 4;



-- Читаем файл и сразу превращаем в jsonb
WITH file_data AS (
    SELECT pg_read_file('/tmp/product.json')::jsonb AS doc
)
-- Теперь работаем с "документом" из файла
SELECT doc -> 'характеристики' AS fragment
FROM file_data;l


\copy (select jsonb_pretty(jsonb_agg(jsonb_build_object('id', id, 'name', name), json_build_object(), json_build_object(), json_build_object())) as product_json from sc1.product) to 'all.json';


для сотрудника по должности сформировать джосон с информацией какой сутрудник (фио) работал с товаром - массив товаров с которыми работал. 

 Инвентаризатор
     2 | Новиков П.С.     | +79990000002     | Оператор склада
     3 | Лебедев В.И.     | +79990000003     | Старший кладовщик
     4 | Попов Е.Н.       | +79990000004     | Инвентаризатор
     5 | Козлов Р.А.      | +79990000005     | Старший кладовщик
     6 | Попов М.В.       | +79990000006     | Оператор склада
     7 | Новиков Р.А.     | +79990000007     | Оператор склада
     8 | Соколов И.И.     | +79990000008     | Менеджер
     9 | Лебедев Р.А.     | +79990000009     | Старший кладовщик
    10 | Сидоров П.С.     | +79990000010     | Кладовщик
    11 | Сидоров В.И.     | +79990000011     | Инвентаризатор
    12 | Попов А.А.       | +79990000012     | Старший кладовщик
    13 | Петров В.И.      | +79990000013     | Старший кладовщик
    14 | Иванов С.П.      | +79990000014     | Старший кладовщик
    15 | Сидоров А.А.     | +79990000015     | Старший кладовщик
    16 | Кузнецов Е.Н.    | +79990000016     | Инвентаризатор







create or replace function sc1.get_array_of_product()


select jsonb_pretty(jsonb_agg(jsonb_build_object('id', id, 'name', name))) as product_json from sc1.product;

create or replace function sc1.get_array_of_product(p_job_title varchar)
returns table
as $$
    return query
    select jsonb_pretty(jsonb_agg(jsonb_build_object('ФИО', e.full_name, 'Продукт', p.id)))
    as contact_json from sc1.inventory i join sc1.employee e on e.id = i.employee_id where i.product_id = p_product_id;
    
    from sc1.employee e join sc1.inventory i on e.

return  query
$$ language plpgsql;


create or replace function sc1.get_array_of_product(p_employee_id integer)
returns table (json_products text)
as $$
begin
    return query
    select jsonb_pretty(jsonb_agg(jsonb_build_object('ФИО', e.full_name, 'Продукт', p.id)))
    from sc1.inventory i join sc1.product p on p.id = i.product_id join sc1.employee e on e.id = i.employee_id where e.id = p_employee_id
    group by e.full_name;
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
