-- 13. Определить товар или товары с максимальным суммарным
-- количеством поступлений, используя вложенные подзапросы
-- с тремя уровнями вложенности.

SELECT
    p.id,
    p.name

FROM sc1.product AS p

WHERE p.id IN (

    SELECT ai.product_id
    FROM sc1.arrival_item AS ai

    GROUP BY ai.product_id

    HAVING SUM(ai.quantity) = (

        SELECT MAX(t.total_quantity)

        FROM (

            SELECT
                SUM(ai2.quantity) AS total_quantity

            FROM sc1.arrival_item AS ai2

            GROUP BY ai2.product_id

        ) AS t
    )
);
