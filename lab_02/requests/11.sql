-- 11. Создать временную таблицу best_selling, содержащую
-- суммарное количество выданных единиц каждого товара,
-- используя инструкцию SELECT INTO TEMP TABLE.

SELECT
    product_id,
    SUM(quantity) AS total_quantity

INTO TEMP TABLE best_selling

FROM sc1.expense_item

GROUP BY product_id;
