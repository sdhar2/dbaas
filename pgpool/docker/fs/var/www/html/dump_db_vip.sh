#!/bin/bash
DB=$1
VIP=$2
DBUSER=$3
DUMPTYPE=$4
now=$(date +"%Y-%m-%d-%H.%M.%S")
count=0
export PGPOOLADMIN_USERNAME=postgres
openssl rsautl -inkey /key.txt -decrypt </output.bin >> /dev/null
export PGPOOL_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f2`
export PGPOOLADMIN_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f3`
export DBPASSWD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f4`
export PGPASSWORD=${DBPASSWD}
PRIMARY=`/var/www/html/where_is_primary_dbnode.sh $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD`
output=""
while [ "$output" == "" ]; do
  export output=`psql -h localhost -p 9999 -U pgpool_checker -w -P "footer=off" -P "tuples_only" -d postgres -c "SELECT 1;"`
  sleep 1
  count=`expr $count + 1`
  if [ $count -gt 10 ]; then
    output="";
  fi
done
if [ $count -gt 10 ]; then
  echo "ERROR: Could not connect to database from pgpool.  Exiting."
  exit 1
fi
if [ "$DB" != "ALL" ]; then
  /usr/pgsql-9.3/bin/pg_dump -U $DBUSER -h $PRIMARY -p 5432 -c -C -w -d $DB -f /usr/local/dbbackups/$DB.$DUMPTYPE.$2.$now.dmp
else
  /usr/pgsql-9.3/bin/psql -U $DBUSER -h $PRIMARY -p 5432 -w -c "SELECT datname FROM pg_database WHERE datistemplate = false;" | egrep -v 'datname|-----|rows|postgres' | tr -d ' ' > /tmp/dblist.$$
  LISTOFDBS=`cat /tmp/dblist.$$`
  touch /usr/local/dbbackups/ALL.$DUMPTYPE.$2.$now.dmp
  for DBLIST in $LISTOFDBS; do 
    /usr/pgsql-9.3/bin/pg_dump -U $DBUSER -h $PRIMARY -p 5432 -c -C -w -d $DBLIST -f /usr/local/dbbackups/$DBLIST.$DUMPTYPE.$2.$now.dmp 
    echo "/usr/local/dbbackups/$DBLIST.$DUMPTYPE.$2.$now.dmp" >> /usr/local/dbbackups/ALL.$DUMPTYPE.$2.$now.dmp
  done
  rm -f /tmp/dblist.$$
fi
