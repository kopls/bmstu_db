SELECT DISTINCT p1.id, p1.name, p1.unit
FROM sc1.product AS p1
JOIN sc1.product AS p2
    ON p1.unit = p2.unit
WHERE p1.id <> p2.id
ORDER BY p1.unit, p1.name, p1.id;
