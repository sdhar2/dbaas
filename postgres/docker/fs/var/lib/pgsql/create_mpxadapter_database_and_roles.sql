--- Dropping database ---
DROP DATABASE IF EXISTS mpxadapterdb;

--- Dropping users ---
--DROP USER IF EXISTS mpxadapter;

--- Creating user mpxadapter ---
CREATE USER mpxadapter WITH ENCRYPTED PASSWORD 'mpxadapter';

--- Creating database ---
CREATE DATABASE mpxadapterdb
    WITH OWNER = mpxadapter
       TABLESPACE = pg_default;

CREATE CAST (VARCHAR AS JSON) WITHOUT FUNCTION AS IMPLICIT;

