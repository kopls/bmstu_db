-- 9. Классифицировать приходы по году оформления:
-- текущий год, прошлый год или более ранний период,
-- используя простое выражение CASE.

SELECT
    id,
    arrival_time,

    CASE EXTRACT(YEAR FROM arrival_time)
        WHEN EXTRACT(YEAR FROM CURRENT_DATE)
            THEN 'Текущий год'

        WHEN EXTRACT(YEAR FROM CURRENT_DATE) - 1
            THEN 'Прошлый год'

        ELSE 'Более ранний приход'
    END AS arrival_period

FROM sc1.arrival;
