BEGIN;

-- =========================================
-- 16. Однострочный INSERT
-- =========================================

-- Добавить тестовый товар.

-- 16. Добавить в таблицу товаров одну тестовую запись
-- с помощью однострочной инструкции INSERT INTO ... VALUES.

INSERT INTO sc1.product (
    id,
    name,
    unit,
    article,
    description
)
VALUES (
    2147000001,
    'Test product',
    'pcs',
    'LAB2-2147000001',
    'Тестовый товар для лабораторной работы'
)
RETURNING *;


-- =========================================
-- 17. Многострочный INSERT с подзапросом
-- =========================================

-- Добавить до трёх позиций в первый приход.
-- Товары выбираются из существующей таблицы.

INSERT INTO sc1.arrival_item (
    id,
    arrival_id,
    product_id,
    quantity,
    unit_price
)

SELECT
    (
        SELECT COALESCE(MAX(id), 0)
        FROM sc1.arrival_item
    ) + ROW_NUMBER() OVER (ORDER BY p.id),

    a.id,
    p.id,
    10,
    100.000

FROM (
    SELECT id
    FROM sc1.product
    WHERE id <> 2147000001
    ORDER BY id
    LIMIT 3
) AS p

CROSS JOIN (
    SELECT id
    FROM sc1.arrival
    ORDER BY id
    LIMIT 1
) AS a

RETURNING *;


-- =========================================
-- 18. Простой UPDATE
-- =========================================

-- Увеличить закупочную цену
-- первой позиции прихода на 10%.

UPDATE sc1.arrival_item

SET unit_price = unit_price * 1.10

WHERE id = (
    SELECT MIN(id)
    FROM sc1.arrival_item
)

RETURNING *;


-- =========================================
-- 19. UPDATE с подзапросом в SET
-- =========================================

-- Установить цену первой позиции прихода
-- равной средней закупочной цене её товара.

UPDATE sc1.arrival_item AS ai

SET unit_price = (
    SELECT AVG(ai2.unit_price)
    FROM sc1.arrival_item AS ai2
    WHERE ai2.product_id = ai.product_id
)

WHERE ai.id = (
    SELECT MIN(id)
    FROM sc1.arrival_item
)

RETURNING *;


-- =========================================
-- 20. Простой DELETE
-- =========================================

-- Удалить тестовый товар из задания 16.

DELETE FROM sc1.product

WHERE id = 2147000001

RETURNING *;


-- =========================================
-- 21. DELETE с коррелированным подзапросом
-- =========================================

-- Удалить один товар, который:
-- 1. Ни разу не поступал.
-- 2. Ни разу не выдавался.
-- 3. Не участвовал в инвентаризации.

DELETE FROM sc1.product AS p

WHERE p.id IN (

    SELECT p2.id

    FROM sc1.product AS p2

    WHERE NOT EXISTS (
        SELECT 1
        FROM sc1.arrival_item AS ai
        WHERE ai.product_id = p2.id
    )

    AND NOT EXISTS (
        SELECT 1
        FROM sc1.expense_item AS ei
        WHERE ei.product_id = p2.id
    )

    AND NOT EXISTS (
        SELECT 1
        FROM sc1.inventory AS i
        WHERE i.product_id = p2.id
    )

    ORDER BY p2.id
    LIMIT 1
)

RETURNING *;


-- Отменяем ВСЕ изменения заданий 16–21.

ROLLBACK;
