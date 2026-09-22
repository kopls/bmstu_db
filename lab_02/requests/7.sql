-- 7. Вычислить среднюю стоимость прихода двумя способами:
-- с помощью агрегатной функции AVG и деления SUM на COUNT.
-- Учитываются только приходы, содержащие хотя бы одну позицию.

SELECT
    AVG(t.total_cost) AS actual_avg,
    SUM(t.total_cost) / NULLIF(COUNT(*), 0) AS calculated_avg
FROM (
    SELECT
        arrival_id,
        SUM(unit_price * quantity) AS total_cost
    FROM sc1.arrival_item
    GROUP BY arrival_id
) AS t;
