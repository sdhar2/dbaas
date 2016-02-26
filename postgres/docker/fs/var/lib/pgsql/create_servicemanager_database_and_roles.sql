--- Dropping database ---
DROP DATABASE IF EXISTS serviceManager;

--- Dropping users ---
--DROP USER IF EXISTS smAdmin;

--- Creating user smAdmin ---
CREATE USER smAdmin WITH ENCRYPTED PASSWORD 'smAdmin';

--- Creating database ---
CREATE DATABASE serviceManager
    WITH OWNER = smAdmin
       TABLESPACE = pg_default;

