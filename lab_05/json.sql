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















