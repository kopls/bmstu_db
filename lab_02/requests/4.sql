SELECT
    id,
    arrival_time,
    provider_id,
    invoice_num
FROM sc1.arrival
WHERE provider_id IN (
    SELECT id
    FROM sc2.provider
    ORDER BY id
    LIMIT 3
);
