SELECT
    p.id,
    p.name
FROM sc1.product AS p
WHERE EXISTS (
    SELECT 1
    FROM sc1.expense_item AS ei
    WHERE ei.product_id = p.id
);
