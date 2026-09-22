-- 8. Для каждого товара определить среднюю, минимальную
-- и максимальную закупочную цену с помощью скалярных
-- подзапросов в выражениях столбцов SELECT.

SELECT
    p.id,
    p.name,

    (
        SELECT AVG(ai.unit_price)
        FROM sc1.arrival_item AS ai
        WHERE ai.product_id = p.id
    ) AS avg_price,

    (
        SELECT MIN(ai.unit_price)
        FROM sc1.arrival_item AS ai
        WHERE ai.product_id = p.id
    ) AS min_price,

    (
        SELECT MAX(ai.unit_price)
        FROM sc1.arrival_item AS ai
        WHERE ai.product_id = p.id
    ) AS max_price

FROM sc1.product AS p;
