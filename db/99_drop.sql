-- Removes everything created by 00_init.sql (extensions in "public" are left alone).
SET client_min_messages = warning;
DROP SCHEMA IF EXISTS steam CASCADE;
