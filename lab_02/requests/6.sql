SELECT
    ai.id,
    ai.product_id,
    ai.unit_price
FROM sc1.arrival_item AS ai
WHERE ai.unit_price > ALL (
    SELECT ai2.unit_price
    FROM sc1.arrival_item AS ai2
    WHERE ai2.product_id = ai.product_id
      AND ai2.id <> ai.id
);
