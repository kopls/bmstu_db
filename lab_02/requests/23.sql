-- 23. Построить иерархию мест хранения, начиная с корневых
-- помещений, и определить глубину вложенности каждого объекта.
-- Использовать рекурсивное CTE с конструкцией WITH RECURSIVE.

WITH RECURSIVE location_tree AS (

    -- Начальный элемент:
    -- места хранения без родителя.

    SELECT
        sl.id,
        sl.name,
        sl.parent_location_id,

        0 AS depth,

        ARRAY[sl.id] AS path

    FROM sc1.storage_location AS sl

    WHERE sl.parent_location_id IS NULL

    UNION ALL

    -- Рекурсивный элемент:
    -- ищем вложенные места хранения.

    SELECT
        child.id,
        child.name,
        child.parent_location_id,

        lt.depth + 1,

        lt.path || child.id

    FROM sc1.storage_location AS child

    JOIN location_tree AS lt
        ON child.parent_location_id = lt.id

    WHERE NOT child.id = ANY(lt.path)
)

SELECT
    id,
    name,
    parent_location_id,
    depth

FROM location_tree

ORDER BY path;
