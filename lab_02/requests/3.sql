SELECT
    id,
    name,
    description
FROM sc1.product
WHERE name LIKE '%Болт%'
   OR description LIKE '%болт%';
