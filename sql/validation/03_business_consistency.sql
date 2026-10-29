-- Kaggle取得スナップショットの確認用。別データ版では期待件数を変更する。
-- SELECTによる確認SQL。NG行があってもSQL自体は正常終了する。
USE ROLE THELOOK_ETL_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE THELOOK_WH;
USE DATABASE THELOOK_DB;
USE SCHEMA STAGING;

-- 元データで確認した4明細の不一致を可視化する。自動修正しない。
-- 期待：ORDER_ID=56、ORDER_ITEM_ID=88〜91、注文側USER_ID=56、明細側=44。
SELECT oi.id AS ORDER_ITEM_ID, oi.order_id,
       o.user_id AS ORDERS_USER_ID, oi.user_id AS ORDER_ITEMS_USER_ID
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.user_id IS DISTINCT FROM oi.user_id
ORDER BY oi.id;

-- 期待：0件。
SELECT COUNT(*) AS PRODUCT_MISMATCHES
FROM order_items oi
JOIN inventory_items ii ON ii.id = oi.inventory_item_id
WHERE oi.product_id IS DISTINCT FROM ii.product_id;

-- 期待：0行。注文あたりの商品数と明細件数の照合。
SELECT o.order_id, o.num_of_item, COALESCE(d.item_count, 0) AS ITEM_COUNT
FROM orders o
LEFT JOIN (
    SELECT order_id, COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
) d ON d.order_id = o.order_id
WHERE o.num_of_item IS DISTINCT FROM COALESCE(d.item_count, 0)
ORDER BY o.order_id;
