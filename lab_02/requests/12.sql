-- 12. Для каждого прихода определить товар с наибольшим
-- поступившим количеством, используя коррелированный
-- подзапрос в предложении FROM с конструкцией LATERAL.

SELECT
    a.id AS arrival_id,
    a.arrival_time,
    best.product_id,
    best.total_quantity

FROM sc1.arrival AS a

JOIN LATERAL (
    SELECT
        ai.product_id,
        SUM(ai.quantity) AS total_quantity

    FROM sc1.arrival_item AS ai

    WHERE ai.arrival_id = a.id

    GROUP BY ai.product_id

    ORDER BY total_quantity DESC, ai.product_id

    LIMIT 1
) AS best ON TRUE;
