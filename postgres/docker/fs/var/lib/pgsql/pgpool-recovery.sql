CREATE OR REPLACE FUNCTION pgpool_recovery(text, text, text)
RETURNS bool
AS '$libdir/pgpool-recovery', 'pgpool_recovery'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION pgpool_remote_start(text, text)
RETURNS bool
AS '$libdir/pgpool-recovery', 'pgpool_remote_start'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION pgpool_pgctl(text, text)
RETURNS bool
AS '$libdir/pgpool-recovery', 'pgpool_pgctl'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION pgpool_switch_xlog(text)
RETURNS text
AS '$libdir/pgpool-recovery', 'pgpool_switch_xlog'
LANGUAGE C STRICT;
