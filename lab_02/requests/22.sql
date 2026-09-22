-- 22. Вычислить среднее количество приходов на одного
-- поставщика, используя простое обобщённое табличное
-- выражение (CTE) с конструкцией WITH.

WITH provider_arrivals AS (

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
)

SELECT
    AVG(arrival_count) AS avg_arrivals

FROM provider_arrivals;
