-- 15. Получить список поставщиков, количество приходов которых
-- превышает среднее количество приходов на одного поставщика,
-- используя GROUP BY и HAVING с вложенным подзапросом.

SELECT
    p.id,
    p.name,
    COUNT(a.id) AS arrival_count

FROM sc2.provider AS p

LEFT JOIN sc1.arrival AS a
    ON a.provider_id = p.id

GROUP BY
    p.id,
    p.name

HAVING COUNT(a.id) > (

    SELECT AVG(t.arrival_count)

    FROM (
        SELECT
            COUNT(a2.id) AS arrival_count

        FROM sc2.provider AS p2

        LEFT JOIN sc1.arrival AS a2
            ON a2.provider_id = p2.id

        GROUP BY p2.id
    ) AS t
);
