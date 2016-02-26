#!/bin/bash
export PGPOOLADMIN_USERNAME=postgres
export PGPOOL_USERNAME=root
export DB_USERNAME=postgres

openssl rsautl -inkey /key.txt -decrypt </output.bin >> /dev/null
export DB_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f1`
export PGPOOL_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f2`
export PGPOOLADMIN_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f3`
export DBPASSWD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f4`

RESTOREFILENAME=$1
VIP=$2
DBUSER=$3
export PGPASSWORD=${DBPASSWD}

date=`date --utc +"%Y-%m-%d %H:%M:%S"`
echo "$date LOG: restore_db_vip is going to restore file named $1." >> /var/log/pgpool/pgpool.log

if [ ! -f $RESTOREFILENAME ]; then
  echo "ERROR: DUMP FILE NOT FOUND. Exiting."
  echo "$date ERROR: DUMP FILE NOT FOUND. Exiting." >> /var/log/pgpool/pgpool.log
  exit 1
fi
DB=`echo $RESTOREFILENAME | cut -d "/" -f5 | cut -d"." -f1`;

## simple integrity check of file(s)
if [ `echo $RESTOREFILENAME | grep ALL | wc -l` -eq 1 ]; then
## ALL file check, checks for presence/integrity of all dump files
  for RESTOREFILEGROUPMEMBER in `cat $RESTOREFILENAME`; do
    GROUPMEMBERDB=`echo $RESTOREFILEGROUPMEMBER | cut -d "/" -f5 | cut -d"." -f1`
    echo $GROUPMEMBERDB
    echo $RESTOREFILEGROUPMEMBER
    if [ `cat $RESTOREFILEGROUPMEMBER | grep 'CREATE DATABASE '$GROUPMEMBERDB | wc -l` -eq 0 ]; then
       echo "ERROR: DUMP FILE $RESTOREFILEGROUPMEMBER fails consistency check (CREATE DATABASE). Exiting."
      echo "$date ERROR: DUMP FILE $RESTOREFILEGROUPMEMBER fails consistency check (CREATE DATABASE). Exiting." >> /var/log/pgpool/pgpool.log
      exit 1
    else
      if [ `cat $RESTOREFILEGROUPMEMBER | grep 'PostgreSQL database dump complete' | wc -l` -eq 0 ]; then
        echo "ERROR: DUMP FILE $RESTOREFILEGROUPMEMBER fails consistency check (DUMP COMPLETE). Exiting." 
        echo "$date ERROR: DUMP FILE $RESTOREFILEGROUPMEMBER fails consistency check (DUMP COMPLETE). Exiting." >> /var/log/pgpool/pgpool.log
        exit 1
      fi
    fi
  done
else
## single file check
  if [ `cat $RESTOREFILENAME | grep 'CREATE DATABASE '$DB | wc -l` -eq 0 ]; then
    echo "ERROR: DUMP FILE $RESTOREFILENAME fails consistency check (CREATE DATABASE). Exiting."
    echo "$date ERROR: DUMP FILE $RESTOREFILENAME fails consistency check (CREATE DATABASE). Exiting." >> /var/log/pgpool/pgpool.log
    exit 1
  else
    if [ `cat $RESTOREFILENAME | grep 'PostgreSQL database dump complete' | wc -l` -eq 0 ]; then
      echo "ERROR: DUMP FILE $RESTOREFILENAME fails consistency check (DUMP COMPLETE). Exiting."
      echo "$date ERROR: DUMP FILE $RESTOREFILENAME fails consistency check (DUMP COMPLETE). Exiting." >> /var/log/pgpool/pgpool.log
      exit 1
    fi
  fi
fi
 
PRIMARY=`/var/www/html/where_is_primary_dbnode.sh $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD`
echo "$date LOG: where is primary pgpool returned $PRIMARY." >> /var/log/pgpool/pgpool.log
PRIMNODE=`/var/www/html/which_is_primary_nodenum.sh $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD`
echo "$date LOG: which is primary pgpool returned $PRIMNODE." >> /var/log/pgpool/pgpool.log
EXISTING_POSTGRES_NODES=`pcp_node_count 5 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD`
CONFIG_POSTGRES_NODES=`cat /tmp/pg.conf | grep -oP '(?<=database/postgres/postgres).*?(?=}|$)' |cut -d" " -f2 | wc -l`

## Check for existence of primary from script.  If it's unsuccessful, exit.
if [ "$PRIMARY" == "" ]; then
  echo "No detected primary in the DBAAS cluster.  Check cluster health and try again."
  echo "$date LOG: No detected primary in the DBAAS cluster.  Check cluster health and try again." >> /var/log/pgpool/pgpool.log 
  exit 1
fi

## Check pool_nodes to make sure primary is connected
FOUNDNODEINFO=0
FOUNDNODEINFOCOUNTER=0
while [ $FOUNDNODEINFO -eq 0 ]; do
  psql -U pgpool_checker -h localhost -p 9999 -d postgres -c "show pool_nodes" > /tmp/restoreprimarydbnode.$$
  FOUNDNODEINFO=`cat /tmp/restoreprimarydbnode.$$ | grep lb_weight | wc -l`
  FOUNDNODEINFOCOUNTER=`expr $FOUNDNODEINFOCOUNTER + 1`
  if [ $FOUNDNODEINFOCOUNTER -gt 6 ]; then
    FOUNDNODEINFO=1
  fi
  if [ $FOUNDNODEINFO -eq 0 ]; then
    sleep 5
  fi
done
FOUNDNODEINFO=`cat /tmp/restoreprimarydbnode.$$ | grep lb_weight | wc -l`
CONNECTEDPRIMARY=`cat /tmp/restoreprimarydbnode.$$ | grep $PRIMARY | grep primary |  grep -v '| 3' | wc -l`
rm -f /tmp/restoreprimarydbnode.$$
if [ $CONNECTEDPRIMARY -eq 0 ]; then
  echo "Detected primary DB $PRIMARY is not connected as a primary to the local DBAAS cluster.  Check cluster health and try again."
  echo "$date LOG: Detected primary DB $PRIMARY is not connected as a primary to the to the local DBAAS cluster.  Check cluster health and try again." >> /var/log/pgpool/pgpool.log
else
##start restore process
##bring down standby nodes but not the primary node
  for i in $(seq 0 `expr $EXISTING_POSTGRES_NODES - 1`); do
    if [ $i -ne $PRIMNODE ]; then
      echo "Bring down node $i."
      echo "$date LOG: Bring down node $i." >> /var/log/pgpool/pgpool.log
      pcp_detach_node 5 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD $i
      sleep 15
    fi
  done

## Two different paths, ALL path and individual DB path
  if [ `echo $RESTOREFILENAME | grep ALL | wc -l` -eq 1 ]; then
## If ALL path, kill all connections and apply filter to remove connection to all non-sysadmin users.

    for pid in $(/bin/ps -ef | /bin/grep ' pgpool: ' | /bin/grep -v grep | egrep -v 'watchdog|worker|heartbeat|lifecheck|PCP' | /bin/awk ""' {print $2}' ); do /bin/kill -9 $pid; done
    sleep 3
    numConnections=`/usr/pgsql-9.3/bin/psql -U $DBUSER -h $PRIMARY -p 5432 -w -c "select count(*) from pg_stat_activity;"`
    connectedUsers=`/usr/pgsql-9.3/bin/psql -U $DBUSER -h $PRIMARY -p 5432 -w -c "select pid, state, state_change, usename from pg_stat_activity;"`
    numConnections=`echo $numConnections | head -3 | tail -l | cut -d " " -f3`
    if [ "$numConnections" -gt "1" ]; then
      echo "ERROR: There are other users connected to the database. Close these connections before performing restore"
      echo "$connectedUsers"
      PERFORMRESTORE=false
    else
      PERFORMRESTORE=true
    fi
    echo "Closing database to users."
    echo "$date LOG: Reloading pgpool to close database to users." >> /var/log/pgpool/pgpool.log
    if [ ! -f /usr/local/etc/pool_passwd.bak ]; then
      cp /usr/local/etc/pool_passwd /usr/local/etc/pool_passwd.bak
    fi
    cp /usr/local/etc/pool_passwd-no-all /usr/local/etc/pool_passwd
    sleep 15
## one last kill all to make sure that everything's gone
     for pid in $(/bin/ps -ef | /bin/grep ' pgpool: ' | /bin/grep -v grep | egrep -v 'watchdog|worker|heartbeat|lifecheck|PCP' | /bin/awk ""' {print $2}' ); do /bin/kill -9 $pid; done
  else
    echo 'Database = '$DB
## kill all connections to the target db
    /var/www/html/kill_db_connections.sh $DB
## reload config to prevent new connections to hit the db
    echo "Closing database to users."
    echo "$date LOG: Reloading pgpool to close database to users." >> /var/log/pgpool/pgpool.log
    if [ ! -f /usr/local/etc/pool_passwd.bak ]; then
      cp /usr/local/etc/pool_passwd /usr/local/etc/pool_passwd.bak
    fi
    cp /usr/local/etc/pool_passwd-no-${DB} /usr/local/etc/pool_passwd 
##    sed -ie "s/pool_passwd = 'pool_passwd'/pool_passwd = 'pool_passwd-no-${DB}'/g" /usr/local/etc/pgpool.conf
##    pgpool -c -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf reload >> /var/log/pgpool/pgpool.log 2>&1

    sleep 15
## one last kill all to make sure that everything's gone
    /var/www/html/kill_db_connections.sh $DB
    sleep 3

    numConnections=`/usr/pgsql-9.3/bin/psql -U $DBUSER -h $PRIMARY -p 5432 -w -c "select count(*) from pg_stat_activity where datname='${DB}';"`
    connectedUsers=`/usr/pgsql-9.3/bin/psql -U $DBUSER -h $PRIMARY -p 5432 -w -c "select pid, state, state_change, usename from pg_stat_activity where datname='${DB}';"`
    numConnections=`echo $numConnections | head -3 | tail -l | cut -d " " -f3`
    if [ "$numConnections" -gt "0" ]; then
      echo "ERROR: There are other users connected to the database. Close these connections before performing restore"
      echo "$connectedUsers"
      PERFORMRESTORE=false
    else
      PERFORMRESTORE=true
    fi
  fi
## do the actual restore of the db

  if [ $PERFORMRESTORE == true ]; then
    if [ `echo $RESTOREFILENAME | grep ALL | wc -l` -eq 1 ]; then 
      for RESTOREFILEGROUPMEMBER in `cat $RESTOREFILENAME`; do
        echo "Starting restore of $RESTOREFILEGROUPMEMBER..."
        /usr/pgsql-9.3/bin/psql -U $DBUSER -h $PRIMARY -p 5432 -w < $RESTOREFILEGROUPMEMBER
      done  
      echo "$date LOG: Completed database restore from $RESTOREFILENAME." >> /var/log/pgpool/pgpool.log
       echo "Opening database to users."
      echo "$date LOG: Reloading pgpool to open database to users." >> /var/log/pgpool/pgpool.log
      cp /usr/local/etc/pool_passwd.bak /usr/local/etc/pool_passwd
      rm -f /usr/local/etc/pool_passwd.bak
      sleep 3
    else
      echo "Starting restore of $RESTOREFILENAME..."
      /usr/pgsql-9.3/bin/psql -U $DBUSER -h $PRIMARY -p 5432 -w < $RESTOREFILENAME
      echo "$date LOG: Completed database restore from $RESTOREFILENAME." >> /var/log/pgpool/pgpool.log
      sleep 15
##reload db with original pool_hba.conf
      echo "Opening database to users."
      echo "$date LOG: Reloading pgpool to open database to users." >> /var/log/pgpool/pgpool.log
      cp /usr/local/etc/pool_passwd.bak /usr/local/etc/pool_passwd
      rm -f /usr/local/etc/pool_passwd.bak
##      sed -ie "s/pool_passwd-no-${DB}/pool_passwd/g" /usr/local/etc/pgpool.conf
##      pgpool -c -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf reload >> /var/log/pgpool/pgpool.log 2>&1
      sleep 3
    fi
  fi

##bring up standby nodes
  for i in $(seq 0 `expr $EXISTING_POSTGRES_NODES - 1`); do
    if [ $i -ne $PRIMNODE ]; then
      echo "Bring up node $i."
      echo "$date LOG: Bring up node $i." >> /var/log/pgpool/pgpool.log
      pcp_attach_node 5 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD $i
      sleep 15
    fi
  done
fi
