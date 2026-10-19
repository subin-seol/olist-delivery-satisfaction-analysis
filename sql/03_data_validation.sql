-- ============================================================
-- Olist E-Commerce Analysis Project
-- 03_data_validation.sql
-- Checks data quality issues before building the analysis layer
-- ============================================================
-- This is plain SQL, no \copy needed, so this can run in either
-- psql or pgAdmin's Query Tool.
--
-- EXPECTED RESULTS on a fresh load (use these to confirm a rebuild):
--  1. Row counts: customers 99,441 | sellers 3,095 | products 32,951 |
--     category_translation 71 | geolocation 1,000,163 | orders 99,441 |
--     order_items 112,650 | order_payments 103,886 | order_reviews 99,224
--  2. Orphaned product / seller references: 0 and 0
--  3. Products missing a category translation: 13 (2 categories:
--     portateis_cozinha_e_preparadores_de_alimentos, pc_gamer).
--     Fixed in 04_transformations.sql STEP 0, so this is expected here.
--  4. Products with no category: 610 | no weight: 2
--     Orders with no delivery date: 2,965 | no approval date: 160
--  5. Order status: delivered 96,478 | shipped 1,107 | canceled 625 |
--     unavailable 609 | invoiced 314 | processing 301 | created 5 |
--     approved 2
--  6. Order dates: 2016-09-04 to 2018-10-17
--  7. Review scores 1-5 only: 11,424 | 3,151 | 8,179 | 19,142 | 57,328
--  8. Payment types: credit_card, boleto, voucher, debit_card, plus 3
--     'not_defined' rows with a value of 0 (not used in this analysis)
--  9. Duplicate order items: 0
-- 10. Zero/negative price or negative freight: 0 and 0
-- 11. Orders with multiple reviews: 547 (max 3 on one order)
-- ============================================================

-- 1. Row counts (re-confirm after import)
SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
ORDER BY table_name;

-- 2. Orphaned foreign keys: order_items referencing products/sellers
-- that don't actually exist (these FKs were deliberately not enforced
-- at table-creation time, so we check them manually here)
SELECT COUNT(*) AS orphaned_product_refs
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS orphaned_seller_refs
FROM order_items oi
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- 3. Products with a category not present in category_translation
-- (would cause NULLs after an eventual join to get English names)
SELECT COUNT(*) AS products_missing_category_translation
FROM products p
LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;

-- Show which raw category names are missing a translation, if any
SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;

-- 4. Null checks on key fields
SELECT
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS products_null_category,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS products_null_weight
FROM products;

SELECT
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS orders_not_delivered,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS orders_null_approved,
    COUNT(*) AS total_orders
FROM orders;

-- 5. Order status breakdown (to understand delivered vs cancelled vs other)
SELECT order_status, COUNT(*) AS row_count
FROM orders
GROUP BY order_status
ORDER BY row_count DESC;

-- 6. Date range sanity check
SELECT MIN(order_purchase_timestamp) AS earliest_order,
       MAX(order_purchase_timestamp) AS latest_order
FROM orders;

-- 7. Review score distribution (1-5 expected; flags any out-of-range values)
SELECT review_score, COUNT(*) AS row_count
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;

-- 8. Payment type breakdown
SELECT payment_type, COUNT(*) AS row_count, ROUND(AVG(payment_value), 2) AS avg_payment
FROM order_payments
GROUP BY payment_type
ORDER BY row_count DESC;

-- 9. Duplicate check: should an order_id + order_item_id combo be unique?
SELECT COUNT(*) - COUNT(DISTINCT (order_id, order_item_id)) AS duplicate_order_items
FROM order_items;

-- 10. Negative or zero values in price/freight (potential data errors)
SELECT
    COUNT(*) FILTER (WHERE price <= 0) AS zero_or_negative_price,
    COUNT(*) FILTER (WHERE freight_value < 0) AS negative_freight
FROM order_items;

-- 11. Orders with more than one review. A plain join from orders to
-- order_reviews would duplicate these orders, so 04_transformations.sql
-- keeps only the most recent review per order.
SELECT COUNT(*) AS orders_with_multiple_reviews,
       MAX(review_count) AS max_reviews_on_one_order
FROM (
    SELECT order_id, COUNT(*) AS review_count
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) multi;
