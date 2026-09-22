-- 10. Классифицировать результаты инвентаризации по фактическому
-- количеству товара: отсутствует, малое, среднее или большое
-- количество, используя поисковое выражение CASE.

SELECT
    id,
    product_id,
    actual_quantity,

    CASE
        WHEN actual_quantity = 0
            THEN 'Отсутствует'

        WHEN actual_quantity < 10
            THEN 'Малое количество'

        WHEN actual_quantity < 100
            THEN 'Среднее количество'

        ELSE 'Большое количество'
    END AS quantity_status

FROM sc1.inventory;
