-- 24. Для каждой позиции прихода вывести закупочную цену,
-- а также среднюю, минимальную и максимальную цены
-- соответствующего товара с использованием оконных функций
-- AVG, MIN и MAX с конструкцией OVER(PARTITION BY ...).

SELECT
    p.id AS product_id,
    p.name AS product_name,

    ai.id AS arrival_item_id,
    ai.unit_price,

    AVG(ai.unit_price) OVER (
        PARTITION BY p.id
    ) AS avg_price,

    MIN(ai.unit_price) OVER (
        PARTITION BY p.id
    ) AS min_price,

    MAX(ai.unit_price) OVER (
        PARTITION BY p.id
    ) AS max_price

FROM sc1.product AS p

LEFT JOIN sc1.arrival_item AS ai
    ON ai.product_id = p.id

ORDER BY
    p.id,
    ai.id;
