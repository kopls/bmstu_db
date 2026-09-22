SELECT
    ai.id,
    ai.arrival_id,
    p.name,
    ai.quantity AS arrived_quantity,

    SUM(ed.quantity) AS expensed_quantity

FROM sc1.arrival_item AS ai

JOIN sc1.expense_distribution AS ed
    ON ed.arrival_item_id = ai.id

JOIN sc1.product AS p
    ON p.id = ai.product_id

GROUP BY
    ai.id,
    ai.arrival_id,
    p.name,
    ai.quantity

HAVING SUM(ed.quantity) >= ai.quantity;
