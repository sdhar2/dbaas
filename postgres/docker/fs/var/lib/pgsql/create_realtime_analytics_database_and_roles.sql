--- Dropping database ---
DROP DATABASE IF EXISTS realtime;

--- Dropping users ---
--DROP USER IF EXISTS arc_bt;

--- Creating user arc_bt ---
CREATE USER arc_bt WITH ENCRYPTED PASSWORD 'arc_sc_2014';

--- Creating database ---
CREATE DATABASE realtime 
    WITH OWNER = arc_bt 
       TABLESPACE = pg_default;

