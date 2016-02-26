--- Creating user CROSADMIN ---
CREATE USER crosadmin WITH ENCRYPTED PASSWORD 'CR0S4DM!N';

--- Creating database ---
CREATE DATABASE CROSDB
    WITH OWNER = crosadmin
       TABLESPACE = pg_default;

