CREATE OR REPLACE FUNCTION pg_catalog.pgpool_regclass(cstring)
RETURNS oid
AS '$libdir/pgpool-regclass', 'pgpool_regclass'
LANGUAGE C STRICT;
