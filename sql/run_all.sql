-- ============================================================
-- Olist E-Commerce Analysis Project
-- run_all.sql
-- Rebuilds the whole database from scratch, in order, stopping at
-- the first error:
--   00 drop  ->  01 create  ->  02 import  ->  03 validate  ->  04 views
-- ============================================================
-- Usage (from a terminal, run from the sql/ folder, because the
-- default data path in 02 is ../data, relative to where psql runs):
--   cd sql
--   psql -U postgres -d olist_ecommerce -f run_all.sql
--
-- To point at a different data folder (default is set in 02):
--   psql -U postgres -d olist_ecommerce -v datadir='/path/to/data' -f run_all.sql
--
-- WARNING: 00_drop_tables.sql deletes all 9 tables (and the views
-- built on them) before rebuilding.
-- ============================================================

\set ON_ERROR_STOP on

-- \ir resolves paths relative to THIS file, so the five scripts only
-- need to sit in the same folder as run_all.sql.
\ir 00_drop_tables.sql
\ir 01_create_tables.sql
\ir 02_import_data.sql
\ir 03_data_validation.sql
\ir 04_transformations.sql
