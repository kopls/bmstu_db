-- 25. Сформировать набор данных с полными дубликатами строк
-- с помощью UNION ALL и устранить повторения в результате
-- запроса, используя оконную функцию ROW_NUMBER().

WITH duplicates AS (

    SELECT
        id,
        name
    FROM sc1.product

    UNION ALL

    SELECT
        id,
        name
    FROM sc1.product
),

numbered AS (

    SELECT
        id,
        name,

        ROW_NUMBER() OVER (
            PARTITION BY id, name
            ORDER BY id
        ) AS rn

    FROM duplicates
)

SELECT
    id,
    name

FROM numbered

WHERE rn = 1

ORDER BY id;
