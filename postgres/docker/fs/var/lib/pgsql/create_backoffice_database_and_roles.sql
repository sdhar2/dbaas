
--- Dropping the schemas ---
DROP SCHEMA IF EXISTS scheduler CASCADE;
DROP SCHEMA IF EXISTS fm CASCADE;
DROP SCHEMA IF EXISTS sms CASCADE;
DROP SCHEMA IF EXISTS support CASCADE;
DROP SCHEMA IF EXISTS simulator CASCADE;

SELECT * FROM pg_stat_activity WHERE datname='ndvr';
SELECT pg_terminate_backend (pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = 'ndvr';

--- Dropping database ---
DROP DATABASE IF EXISTS ndvr;

--- Dropping tablespaces ---
DROP TABLESPACE IF EXISTS ndvr_data;
DROP TABLESPACE IF EXISTS ndvr_log;
DROP TABLESPACE IF EXISTS ndvr_index;

--- Dropping users ---
DROP USER IF EXISTS csadmin;
DROP USER IF EXISTS fmadmin;
DROP USER IF EXISTS smsadmin;
DROP USER IF EXISTS spadmin;
DROP USER IF EXISTS simadmin;
DROP USER IF EXISTS timersadmin;
DROP USER IF EXISTS mcsadmin;

--- Creating database ---
CREATE DATABASE ndvr WITH ENCODING 'UTF8' TEMPLATE template0 TABLESPACE pg_default;


--- Dropping the schema scheduler ---
DROP SCHEMA IF EXISTS scheduler CASCADE;

--- Dropping user ---
DROP USER IF EXISTS csadmin;
--- Creating user csadmin ---
CREATE USER csadmin
        WITH
                SUPERUSER
                CREATEDB
                CREATEROLE
                REPLICATION
                ENCRYPTED PASSWORD 'csadmin';

--- Switching to the csadmin ---
SET ROLE csadmin;


--- Dropping the schema fm ---
DROP SCHEMA IF EXISTS fulfillment CASCADE;

--- Dropping user ---
DROP USER IF EXISTS fmadmin;

--- Creating user fmadmin ---
CREATE USER fmadmin
        WITH
                SUPERUSER
                CREATEDB
                CREATEROLE
                REPLICATION
                ENCRYPTED PASSWORD 'fmadmin';

--- Switching to the fmadmin ---
SET ROLE fmadmin;


--- Dropping the schema sms ---
DROP SCHEMA IF EXISTS sms CASCADE;

--- Dropping user ---
DROP USER IF EXISTS smsadmin;

--- Creating user smsadmin ---
CREATE USER smsadmin
        WITH
                SUPERUSER
                CREATEDB
                CREATEROLE
                REPLICATION
                ENCRYPTED PASSWORD 'smsadmin';

--- Switching to the smsadmin ---
SET ROLE smsadmin;

--- Dropping the schema simulator ---	
DROP SCHEMA IF EXISTS simulator CASCADE; 

--- Dropping user ---
DROP USER IF EXISTS simadmin;

--- Creating user simadmin ---  
CREATE USER simadmin
	WITH 
		SUPERUSER
		CREATEDB
		CREATEROLE
		REPLICATION
		ENCRYPTED PASSWORD 'simadmin';

--- Switching to the simadmin ---		
SET ROLE simadmin;

--- Dropping the schema support ---	
DROP SCHEMA IF EXISTS support CASCADE; 

--- Dropping user ---
DROP USER IF EXISTS spadmin;

--- Creating user spadmin ---  
CREATE USER spadmin
	WITH 
		SUPERUSER
		CREATEDB
		CREATEROLE
		REPLICATION
		ENCRYPTED PASSWORD 'spadmin';

--- Switching to the spadmin ---		
SET ROLE spadmin;


--- Dropping user ---
DROP USER IF EXISTS mcsadmin;
--- Creating user mcsadmin ---
CREATE USER mcsadmin
        WITH
                SUPERUSER
                CREATEDB
                CREATEROLE
                REPLICATION
                ENCRYPTED PASSWORD 'mcsadmin';

--- Dropping user ---
DROP USER IF EXISTS timersadmin;
--- Creating user timersadmin ---
CREATE USER timersadmin
        WITH
                SUPERUSER
                CREATEDB
                CREATEROLE
                REPLICATION
                ENCRYPTED PASSWORD 'timersadmin';

--- Dropping database ---
DROP DATABASE IF EXISTS CIS;
--- Dropping users ---
DROP USER IF EXISTS cis;

CREATE USER CIS WITH ENCRYPTED PASSWORD 'cis';

CREATE DATABASE CIS
  WITH OWNER = CIS
       TABLESPACE = pg_default;

