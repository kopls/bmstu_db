SELECT
    id,
    arrival_time,
    provider_id,
    invoice_num
FROM sc1.arrival
WHERE arrival_time BETWEEN
    CURRENT_TIMESTAMP - INTERVAL '300 days'
    AND CURRENT_TIMESTAMP
ORDER BY arrival_time;
