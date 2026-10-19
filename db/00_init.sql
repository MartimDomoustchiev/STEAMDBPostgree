-- =============================================================================
--  STEAM-style database  (PostgreSQL 14+)
-- =============================================================================
--  Usage (run from inside this folder):
--      createdb steam_db
--      psql -d steam_db -f 00_init.sql
--
--  Everything lives in the "steam" schema. To start over:  psql -d steam_db -f 99_drop.sql
--  To load the schema without sample data, comment out the 12_seed.sql line.
--  See README.md for an overview and sample_queries.sql for example queries.
-- =============================================================================

\set ON_ERROR_STOP on
SET client_min_messages = warning;

CREATE SCHEMA IF NOT EXISTS steam;
SET search_path TO steam, public;

-- new connections to this database see the steam schema without qualifying names
DO $$ BEGIN
    EXECUTE format('ALTER DATABASE %I SET search_path = steam, public', current_database());
END $$;

\ir 01_types.sql
\ir 02_reference.sql
\ir 03_accounts.sql
\ir 04_catalog.sql
\ir 05_store.sql
\ir 06_library.sql
\ir 07_community.sql
\ir 08_inventory_market.sql
\ir 09_indexes.sql
\ir 10_functions_triggers.sql
\ir 11_views.sql
\ir 12_seed.sql
\ir 13_roles.sql
