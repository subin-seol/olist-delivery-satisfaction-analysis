-- ============================================================
-- Olist E-Commerce Analysis Project
-- 00_drop_tables.sql
-- Drops all 9 tables, in reverse dependency order, for a clean rebuild
-- ============================================================
-- CASCADE is used so that foreign key dependent objects are dropped
-- along with the referenced table without needing to worry about
-- exact drop order beyond the general child-before-parent pattern.
-- ============================================================

DROP TABLE IF EXISTS order_reviews CASCADE;
DROP TABLE IF EXISTS order_payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS geolocation CASCADE;
DROP TABLE IF EXISTS category_translation CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
