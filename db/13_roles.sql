-- =============================================================================
-- 13  Roles and privileges (least privilege)
-- =============================================================================
--  steam_readonly : analytics / reporting - SELECT only
--  steam_app      : the game-store backend - normal DML, but it cannot rewrite
--                   history (wallet ledger, price history) or reference data
--
--  These are NOLOGIN group roles. Create real logins and add them, e.g.:
--      CREATE ROLE store_backend LOGIN PASSWORD '...' IN ROLE steam_app;
--  Roles are cluster-wide, so 99_drop.sql does not remove them.
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'steam_readonly') THEN
        CREATE ROLE steam_readonly NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'steam_app') THEN
        CREATE ROLE steam_app NOLOGIN;
    END IF;
END $$;

-- nobody gets anything by default
REVOKE ALL ON SCHEMA steam FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA steam FROM PUBLIC;

-- read-only
GRANT USAGE  ON SCHEMA steam                 TO steam_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA steam   TO steam_readonly;          -- includes views

-- application
GRANT USAGE ON SCHEMA steam                                       TO steam_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA steam TO steam_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA steam               TO steam_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA steam                     TO steam_app;

-- history and reference data are not editable by the application
REVOKE UPDATE, DELETE ON wallet_transactions, app_prices FROM steam_app;
REVOKE INSERT, UPDATE, DELETE ON currencies, countries, languages, platforms FROM steam_app;
