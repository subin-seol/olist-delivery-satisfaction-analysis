-- ============================================================
-- Olist E-Commerce Analysis Project
-- 04_transformations.sql
-- Builds analysis-ready views for the Power BI dashboard
-- Business question: Does delivery performance affect customer
-- satisfaction, and where is that risk concentrated?
-- ============================================================
-- These are VIEWS (not materialized), so they always reflect the
-- current underlying data. Power BI connects directly to these
-- instead of the raw tables, keeping join logic centralized here
-- rather than duplicated inside Power BI's query editor.
-- This file is safe to re-run: views are dropped and rebuilt, and
-- the reference-data fix below is an upsert.
-- ============================================================

-- ------------------------------------------------------------
-- STEP 0: reference-data fix
-- Two product categories in products.csv have no row in the
-- translation file (found in 03_data_validation.sql). Add them here
-- so the fix is part of the pipeline and survives a rebuild.
-- Names use underscores to match the rest of the translation table.
-- ------------------------------------------------------------
INSERT INTO category_translation (product_category_name, product_category_name_english)
VALUES
    ('portateis_cozinha_e_preparadores_de_alimentos', 'kitchen_portables_and_food_preparers'),
    ('pc_gamer', 'pc_gamer')
ON CONFLICT (product_category_name)
DO UPDATE SET product_category_name_english = EXCLUDED.product_category_name_english;

-- Drop views first (dependents before the base view) so definitions
-- can change between runs without "cannot change column type" errors.
DROP VIEW IF EXISTS v_seller_performance;
DROP VIEW IF EXISTS v_category_performance;
DROP VIEW IF EXISTS v_state_performance;
DROP VIEW IF EXISTS v_monthly_delivery_trend;
DROP VIEW IF EXISTS v_order_delivery_reviews;

-- ------------------------------------------------------------
-- VIEW 1: v_order_delivery_reviews
-- Core fact table: one row per delivered order, with delivery
-- timing, on-time flag, and review score attached.
-- This is the base view most dashboard visuals will pull from.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_delivery_reviews AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_state,
    c.customer_city,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    -- Delivery time in days (purchase to actual delivery)
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) AS delivery_days,
    -- Estimated delivery dates are date-only (always 00:00:00), so
    -- lateness is judged on calendar dates. Comparing full timestamps
    -- would flag ~1,300 orders as late that arrived on the promised day
    -- (and averaged 4.0 stars). Positive = late, zero/negative = on-time.
    (o.order_delivered_customer_date::DATE - o.order_estimated_delivery_date::DATE) AS days_vs_estimate,
    CASE
        WHEN o.order_delivered_customer_date::DATE <= o.order_estimated_delivery_date::DATE THEN 'On-time'
        ELSE 'Late'
    END AS delivery_status,
    r.review_score
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
-- Some orders have more than one review (547 orders, up to 3 each), which
-- would duplicate order rows and skew every count built on this view.
-- Keep a single review per order: the most recent one.
LEFT JOIN (
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM order_reviews
    ORDER BY order_id, review_creation_date DESC, review_answer_timestamp DESC
) r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;


-- ------------------------------------------------------------
-- VIEW 2: v_monthly_delivery_trend
-- Average delivery time and review score by month, for the
-- trend line chart.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_monthly_delivery_trend AS
SELECT
    DATE_TRUNC('month', order_purchase_timestamp)::DATE AS order_month,
    COUNT(*) AS total_orders,
    ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(100.0 * COUNT(*) FILTER (WHERE delivery_status = 'On-time') / COUNT(*), 1) AS on_time_pct
FROM v_order_delivery_reviews
-- Sep-Dec 2016 has only 1, 265 and 1 delivered orders in three
-- non-consecutive months (no Nov), which makes the trend line noisy
-- and misleading. Start the series at Jan 2017 (750+ orders/month).
WHERE order_purchase_timestamp >= DATE '2017-01-01'
GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY order_month;


-- ------------------------------------------------------------
-- VIEW 3: v_state_performance
-- Delivery time, on-time rate, and review score by customer
-- state, for the map visual.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_state_performance AS
SELECT
    customer_state,
    COUNT(*) AS total_orders,
    ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(100.0 * COUNT(*) FILTER (WHERE delivery_status = 'On-time') / COUNT(*), 1) AS on_time_pct
FROM v_order_delivery_reviews
GROUP BY customer_state
ORDER BY avg_delivery_days DESC;


-- ------------------------------------------------------------
-- VIEW 4: v_category_performance
-- Delivery and review performance by product category
-- (English names, via category_translation), for identifying
-- which categories are the biggest risk contributors.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_category_performance AS
SELECT
    COALESCE(ct.product_category_name_english, 'Uncategorized') AS category,
    COUNT(DISTINCT odr.order_id) AS total_orders,
    ROUND(AVG(odr.delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(odr.review_score), 2) AS avg_review_score,
    ROUND(100.0 * COUNT(DISTINCT odr.order_id) FILTER (WHERE odr.delivery_status = 'On-time')
          / COUNT(DISTINCT odr.order_id), 1) AS on_time_pct
FROM v_order_delivery_reviews odr
JOIN order_items oi ON odr.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
GROUP BY COALESCE(ct.product_category_name_english, 'Uncategorized')
-- Minimum volume so tiny categories (e.g. 2 orders) don't top the
-- "worst performers" ranking. 63 of 74 categories have 30+ orders.
HAVING COUNT(DISTINCT odr.order_id) >= 30
ORDER BY avg_review_score ASC;


-- ------------------------------------------------------------
-- VIEW 5: v_seller_performance
-- Delivery and review performance by seller, filtered to
-- sellers with a meaningful order volume (avoids single-order
-- sellers skewing the "worst performer" ranking).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_seller_performance AS
SELECT
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT odr.order_id) AS total_orders,
    ROUND(AVG(odr.delivery_days), 1) AS avg_delivery_days,
    ROUND(AVG(odr.review_score), 2) AS avg_review_score,
    ROUND(100.0 * COUNT(DISTINCT odr.order_id) FILTER (WHERE odr.delivery_status = 'On-time')
          / COUNT(DISTINCT odr.order_id), 1) AS on_time_pct
FROM v_order_delivery_reviews odr
JOIN order_items oi ON odr.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
GROUP BY s.seller_id, s.seller_state
HAVING COUNT(DISTINCT odr.order_id) >= 10
ORDER BY avg_review_score ASC;


-- ------------------------------------------------------------
-- Quick check: preview each view
-- ------------------------------------------------------------
SELECT * FROM v_order_delivery_reviews LIMIT 5;
SELECT * FROM v_monthly_delivery_trend LIMIT 5;
SELECT * FROM v_state_performance LIMIT 5;
SELECT * FROM v_category_performance LIMIT 5;
SELECT * FROM v_seller_performance LIMIT 5;
