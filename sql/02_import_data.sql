-- ============================================================
-- Olist E-Commerce Analysis Project
-- 02_import_data.sql
-- Bulk-loads the 9 source CSVs using psql's native \copy command
-- ============================================================
-- \copy is a psql meta-command (client-side), not standard SQL, so
-- run this from a real psql session, not pgAdmin's Query Tool:
--   psql -U postgres -d olist_ecommerce -f 02_import_data.sql
--
-- \copy reads files with YOUR user's permissions (unlike server-side
-- COPY, which hit "Permission denied" on macOS), and loads all ~1.55M
-- rows in seconds (the pgAdmin import wizard took 380+ s per table).
--
-- DATA FOLDER: the default (../data) is relative to the folder you
-- run psql from, so run this from the sql/ folder, or override it:
--   psql -U postgres -d olist_ecommerce -v datadir='/other/path' -f 02_import_data.sql
--
-- Import order matters: tables with foreign keys (orders, order_items,
-- order_payments, order_reviews) must load AFTER the tables they
-- reference (customers, orders) or the FK constraint rejects the rows.
-- ============================================================

\if :{?datadir}
\else
    \set datadir '../data'
\endif

-- Move psql into the data folder so the file names below are relative.
-- Remember the starting folder so we can return to it afterwards
-- (run_all.sql's \ir calls depend on the working directory).
\set startdir `pwd`
\cd :datadir

\timing on

-- Step 1: tables with no foreign key dependencies (any order)
\copy customers FROM 'olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy sellers FROM 'olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy products FROM 'olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy category_translation FROM 'product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy geolocation FROM 'olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- Step 2: orders depends on customers, must come after
\copy orders FROM 'olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- Step 3: these depend on orders, must come after orders finishes
\copy order_items FROM 'olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy order_payments FROM 'olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy order_reviews FROM 'olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

\timing off

-- Return to the starting folder.
\cd :startdir
