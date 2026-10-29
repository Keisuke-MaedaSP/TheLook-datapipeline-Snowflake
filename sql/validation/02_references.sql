-- Kaggle取得スナップショットの確認用。別データ版では期待件数を変更する。
-- SELECTによる確認SQL。NG行があってもSQL自体は正常終了する。
USE ROLE THELOOK_ETL_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE THELOOK_WH;
USE DATABASE THELOOK_DB;
USE SCHEMA STAGING;

-- NULLの外部キー候補は除外。NULL数の適否は別に確認する。
SELECT 'products.distribution_center_id -> distribution_centers.id' AS CHECK_NAME,
       COUNT(*) AS MISSING_COUNT
FROM products c
WHERE c.distribution_center_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM distribution_centers p WHERE p.id = c.distribution_center_id)
UNION ALL
SELECT 'inventory_items.product_id -> products.id' AS CHECK_NAME,
       COUNT(*) AS MISSING_COUNT
FROM inventory_items c
WHERE c.product_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM products p WHERE p.id = c.product_id)
UNION ALL
SELECT 'inventory_items.product_distribution_center_id -> distribution_centers.id' AS CHECK_NAME,
       COUNT(*) AS MISSING_COUNT
FROM inventory_items c
WHERE c.product_distribution_center_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM distribution_centers p WHERE p.id = c.product_distribution_center_id)
UNION ALL
SELECT 'orders.user_id -> users.id' AS CHECK_NAME,
       COUNT(*) AS MISSING_COUNT
FROM orders c
WHERE c.user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM users p WHERE p.id = c.user_id)
UNION ALL
SELECT 'order_items.order_id -> orders.order_id' AS CHECK_NAME,
       COUNT(*) AS MISSING_COUNT
FROM order_items c
WHERE c.order_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM orders p WHERE p.order_id = c.order_id)
UNION ALL
SELECT 'order_items.product_id -> products.id' AS CHECK_NAME,
       COUNT(*) AS MISSING_COUNT
FROM order_items c
WHERE c.product_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM products p WHERE p.id = c.product_id)
UNION ALL
SELECT 'order_items.inventory_item_id -> inventory_items.id' AS CHECK_NAME,
       COUNT(*) AS MISSING_COUNT
FROM order_items c
WHERE c.inventory_item_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM inventory_items p WHERE p.id = c.inventory_item_id)
UNION ALL
SELECT 'order_items.user_id -> users.id' AS CHECK_NAME,
       COUNT(*) AS MISSING_COUNT
FROM order_items c
WHERE c.user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM users p WHERE p.id = c.user_id)
UNION ALL
SELECT 'events.user_id -> users.id' AS CHECK_NAME,
       COUNT(*) AS MISSING_COUNT
FROM events c
WHERE c.user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM users p WHERE p.id = c.user_id);
