-- 14. Для каждого товара определить среднюю, минимальную
-- и максимальную закупочную цену, используя группировку
-- GROUP BY без предложения HAVING.

SELECT
    p.id,
    p.name,

    AVG(ai.unit_price) AS avg_price,
    MIN(ai.unit_price) AS min_price,
    MAX(ai.unit_price) AS max_price

FROM sc1.product AS p

LEFT JOIN sc1.arrival_item AS ai
    ON ai.product_id = p.id

GROUP BY
    p.id,
    p.name

ORDER BY p.id;
