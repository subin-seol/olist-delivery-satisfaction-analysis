-- ============================================================
-- Olist E-Commerce Analysis Project
-- 05_export_for_powerbi.sql
-- Exports the 5 analysis views to CSV so Power BI Desktop (Windows)
-- can load them without a network connection to the Mac database.
-- ============================================================
-- Run from psql (uses client-side \copy, same as 02_import_data.sql):
--   psql -U postgres -d olist_ecommerce -f 05_export_for_powerbi.sql
-- The default output folder (../powerbi_export) is relative to the
-- folder you run psql from, so run this from the sql/ folder, or
-- override it:
--   psql -U postgres -d olist_ecommerce -v outdir='/other/path' -f 05_export_for_powerbi.sql
--
-- Output: 5 CSV files in the folder below. Copy that whole folder to
-- the Windows machine (USB, cloud drive, or email), then follow
-- Power_BI_Build_Guide.md.
-- ============================================================

\if :{?outdir}
\else
    \set outdir '../powerbi_export'
\endif

-- Create the folder if it does not exist yet (runs a shell command on the Mac).
-- \! does not expand psql variables, so pass the path via an env var.
\setenv OUTDIR :outdir
\! mkdir -p "$OUTDIR"
-- Remember the starting folder so we can return to it afterwards
-- (run_all.sql's \ir calls depend on the working directory).
\set startdir `pwd`
\cd :outdir

\copy (SELECT * FROM v_order_delivery_reviews) TO 'v_order_delivery_reviews.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy (SELECT * FROM v_monthly_delivery_trend)  TO 'v_monthly_delivery_trend.csv'  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy (SELECT * FROM v_state_performance)       TO 'v_state_performance.csv'       WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy (SELECT * FROM v_category_performance)    TO 'v_category_performance.csv'    WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy (SELECT * FROM v_seller_performance)      TO 'v_seller_performance.csv'      WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- Sanity check: row counts the CSVs should have (excluding header row)
SELECT 'v_order_delivery_reviews' AS view_name, COUNT(*) AS rows_expected FROM v_order_delivery_reviews  -- 96,470
UNION ALL SELECT 'v_monthly_delivery_trend', COUNT(*) FROM v_monthly_delivery_trend
UNION ALL SELECT 'v_state_performance',      COUNT(*) FROM v_state_performance
UNION ALL SELECT 'v_category_performance',   COUNT(*) FROM v_category_performance
UNION ALL SELECT 'v_seller_performance',     COUNT(*) FROM v_seller_performance;

-- Return to the starting folder.
\cd :startdir
