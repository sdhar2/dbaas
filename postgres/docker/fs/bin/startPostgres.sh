#!/bin/bash

touch /var/run/postgres_starting
export PGPOOLADMIN_USERNAME=postgres
export PGPOOL_USERNAME=root
export DB_USERNAME=postgres

openssl rsautl -inkey /key.txt -decrypt </output.bin
export DB_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f1`
export PGPOOL_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f2`
export PGPOOLADMIN_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f3`

## make sure owner of data directory is postgres
chown postgres:postgres /var/lib/pgsql/9.3/data

## if ssh keys don't exist for postgres, generate them

if [ ! -f /var/lib/pgsql/.ssh/id_rsa ]; then
  su - postgres -c "/var/lib/pgsql/keygen.expect /var/lib/pgsql/.ssh"
fi

## if there is an artifact version of postgres running that's left over from a prior run, attempt to kill it

if [ `ps -ef | grep /usr/pgsql-9.3/bin | wc -l` -ne 1 ]; then
  su - postgres -c "/usr/pgsql-9.3/bin/pg_ctl -w -D /var/lib/pgsql/9.3/data stop -m fast"
fi

## if there is a trigger file that's left over from a prior run, remove it
if [ -f /var/lib/pgsql/9.3/data/trigger ]; then
  rm -f /var/lib/pgsql/9.3/data/trigger
fi

sed -ie  '/host all all/d' /var/lib/pgsql/9.3/data/pg_hba.conf
sed -ie  '/host replication postgres/d' /var/lib/pgsql/9.3/data/pg_hba.conf
sed -ie  '/pgpool_checker/d' /var/lib/pgsql/9.3/data/pg_hba.conf

OTHERDBNODEFOUND=0
MASTERFOUND="none"

# check that confd is up by checking its status file... if not there loop
while [ ! -f /tmp/postgres.conf ]; do
  sleep 5
done

POSTGRES_NODES=`cat /tmp/postgres.conf | grep -oP '(?<=database/postgres/postgres).*?(?=}|$)' |cut -d" " -f2`
if [ -n "$POSTGRES_NODES" ]
then
    for server in $POSTGRES_NODES; do
        if [ $HOST_IP != $server ]
        then
            date=`date +"%Y-%m-%d %H:%M:%S %Z"`
            echo "< $date >DEBUG: startPostgres: $HOST_IP and $server are unequal, so pinging $server." >> /var/log/postgres/postgres.log
            ping -c1 $server > /dev/null 2>&1
            if [ `echo $?` -eq 0 ]
            then
                su - postgres -c "/var/lib/pgsql/dbnode.discover.sh $HOST_IP $server $DB_USERNAME $DB_PASSWORD"
                CAN_I_CONNECT=`su - postgres -c "ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' $DB_USERNAME@$server -p 49154 'echo 2>&1' && echo SSH__OK || echo SSH_NOK"`
                if [ $CAN_I_CONNECT == "SSH__OK" ]; then
                    OTHERDBNODEFOUND=1
                    date=`date +"%Y-%m-%d %H:%M:%S %Z"`
                    echo "< $date >DEBUG: startPostgres: connecting ok to $server." >> /var/log/postgres/postgres.log
                    if [ `su - postgres -c "ssh -T $DB_USERNAME@$server -p 49154 'head -1 /var/lib/pgsql/9.3/data/postgresql.conf 2>/dev/null | wc -l'"` -eq 1 ]; then
                        echo "< $date >DEBUG: startPostgres: searching for postgresql.conf indicated it was there" >> /var/log/postgres/postgres.log
                        if [ `su - postgres -c "ssh -T $DB_USERNAME@$server -p 49154 'head -1 /var/lib/pgsql/9.3/data/recovery.conf 2>/dev/null | wc -l'"` -eq 0 ]; then
                            echo "< $date >DEBUG: startPostgres: searching for recovery.conf indicated it was not there" >> /var/log/postgres/postgres.log
                            TESTPSQL=0
                            PSQLCHECKS=0
                            while [ $TESTPSQL -eq 0 ]; do
                              date=`date +"%Y-%m-%d %H:%M:%S %Z"`
                              TESTPSQL=`psql -U pgpool_checker -h $server -p 5432 -d postgres -c "select 'xyz'" | grep xyz | grep -v grep | wc -l`
                              if [ $TESTPSQL -eq 1 ]; then
                                echo "< $date >DEBUG: startPostgres: connection to the database node $server was successful " >> /var/log/postgres/postgres.log
                                MASTERFOUND=$server
                              fi
                              echo "< $date >DEBUG: startPostgres: connection to the database node $server was unsuccessful " >> /var/log/postgres/postgres.log
                              PSQLCHECKS=`expr $PSQLCHECKS + 1`
                              if [ $PSQLCHECKS -gt 12 ]; then
                                TESTPSQL=1
                                if [ "$MASTERFOUND" == "none" ]; then
                                  echo "< $date >DEBUG: startPostgres: psql connection to the database node $server was unsuccessful after 60 seconds.  This is not a working master... Proceeding." >> /var/log/postgres/postgres.log
                                fi
                              fi
                              sleep 5
                            done
                        fi
                    fi
                fi
            fi
        fi
    done
fi

date=`date +"%Y-%m-%d %H:%M:%S %Z"`
echo "< $date >DEBUG: startPostgres: Found Master Postgres = $MASTERFOUND." >> /var/log/postgres/postgres.log
##
## if I found a master I need to issue a recovery
##
if [ $MASTERFOUND != "none" ]; then
  if [ -f /var/lib/pgsql/9.3/data/postmaster.opts ]; then rm /var/lib/pgsql/9.3/data/postmaster.opts; fi
  if [ -f /var/lib/pgsql/9.3/data/postmaster.pid ]; then rm /var/lib/pgsql/9.3/data/postmaster.pid; fi
  if [ -f /var/lib/pgsql/9.3/data/recovery.done ]; then rm /var/lib/pgsql/9.3/data/recovery.done; fi
  su - postgres -c "ssh -T $DB_USERNAME@$MASTERFOUND -p 49154 '/var/lib/pgsql/9.3/data/basebackup.sh /var/lib/pgsql/9.3/data $HOST_IP /var/lib/pgsql/9.3/data $DB_USERNAME $DB_PASSWORD'"
  date=`date +"%Y-%m-%d %H:%M:%S %Z"`
  echo "< $date >DEBUG: startPostgres: completed recovery from $MASTERFOUND." >> /var/log/postgres/postgres.log 
fi

PGPOOL_NODES=`cat /tmp/postgres.conf | grep -oP '(?<=database/pgpool/pgpool).*?(?=}|$)' |cut -d" " -f2`
if [ -n "$PGPOOL_NODES" ] 
then 
    for server in $PGPOOL_NODES; do
	ping -c1 $server > /dev/null 2>&1
	if [ `echo $?` -eq 0 ]
	then
  	    su - postgres -c "/var/lib/pgsql/pgpool.discover.sh $HOST_IP $server $PGPOOL_USERNAME $PGPOOL_PASSWORD"
	fi
    done
fi

chmod 700 /var/lib/pgsql/9.3/data
chmod 777 /tmp
if [ ! -f /var/lib/pgsql/9.3/data/postgresql.conf ]; then
  date=`date +"%Y-%m-%d %H:%M:%S %Z"`
  echo "< $date >LOG: startPostgres: No postgres install found. Installing fresh..." >> /var/log/postgres/postgres.log 
  chown -R postgres:postgres /var/lib/pgsql/9.3/data
  su - postgres -c "/usr/pgsql-9.3/bin/initdb  -D /var/lib/pgsql/9.3/data"
  su - postgres -c "mkdir /var/lib/pgsql/9.3/data/walarchive"
  su - postgres -c "/usr/pgsql-9.3/bin/pg_ctl -w -D /var/lib/pgsql/9.3/data start"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/pgpool-recovery.sql template1"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/pgpool-recovery.sql postgres"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/pgpool-regclass.sql template1"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/pgpool-regclass.sql postgres"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/create_pgpool_user.sql"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/alter_postgres_user.sql"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/create_backoffice_database_and_roles.sql"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/create_servicemanager_database_and_roles.sql"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/create_mpxadapter_database_and_roles.sql"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -d mpxadapterdb -f /var/lib/pgsql/create_cast_for_mpxadapter.sql"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/create_realtime_analytics_database_and_roles.sql"
  su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/create_cros_database_and_roles.sql"  
  su - postgres -c "/usr/pgsql-9.3/bin/pg_ctl -w -D /var/lib/pgsql/9.3/data stop"
  su - postgres -c "cp /var/lib/pgsql/postgresql.conf /var/lib/pgsql/9.3/data/postgresql.conf"
  su - postgres -c "cp /var/lib/pgsql/pg_hba.conf /var/lib/pgsql/9.3/data/pg_hba.conf"
  su - postgres -c "echo $HOST_IP > /var/lib/pgsql/9.3/data/myip"
  su - postgres -c "touch /var/lib/pgsql/9.3/data/recovery.done"
else
  date=`date +"%Y-%m-%d %H:%M:%S %Z"`
  echo "< $date >DEBUG: startPostgres: Existing Postgres install found." >> /var/log/postgres/postgres.log

##Make sure myip is the current IP... it is never good to have this be different than $HOST_IP
  su - postgres -c "echo $HOST_IP > /var/lib/pgsql/9.3/data/myip"

##Make sure latest config options are in place 

if [ "`cat /var/lib/pgsql/9.3/data/pg_hba.conf | grep -i 'crosadmin' | wc -l`" == "0" ]; then
	echo "host    crosdb        	crosadmin     	0.0.0.0/0          	md5" >> /var/lib/pgsql/9.3/data/pg_hba.conf
fi

##The following config options are not specific to larger memory

  sed -ie "s/^\#*archive_mode = on/archive_mode = off/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*wal_keep_segments = 32/wal_keep_segments = 128/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*synchronous_commit = on/synchronous_commit = off/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*bgwriter_delay = 200ms/bgwriter_delay = 400ms/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*effective_io_concurrency = 1/effective_io_concurrency = 2/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*max_connections = 553/max_connections = 1053/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*wal_buffers = 64MB/wal_buffers = 128MB/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*wal_writer_delay = 200ms/wal_writer_delay = 1000ms/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*commit_delay = 0/commit_delay = 40/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*commit_siblings = 5/commit_siblings = 100/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*checkpoint_segments = 59/checkpoint_segments = 512/g" /var/lib/pgsql/9.3/data/postgresql.conf
  sed -ie "s/^\#*wal_keep_segments = 128/wal_keep_segments = 512/g" /var/lib/pgsql/9.3/data/postgresql.conf


##The following config options are specific for 32G memory
  if [ "`cat /proc/meminfo | grep MemTotal | awk ' {print $2} ' | cut -c1-2`" == "32" ]; then
    sed -ie "s/^\#*shared_buffers = 2048MB/shared_buffers = 4096MB/g" /var/lib/pgsql/9.3/data/postgresql.conf
    sed -ie "s/^\#*maintenance_work_mem = 16MB/maintenance_work_mem = 16384MB/g" /var/lib/pgsql/9.3/data/postgresql.conf
    sed -ie "s/^\#*effective_cache_size = 2409MB/effective_cache_size = 16384MB/g" /var/lib/pgsql/9.3/data/postgresql.conf
  fi

##The following config options are specific for 8G memory
  if [ "`cat /proc/meminfo | grep MemTotal | awk ' {print $2} ' | cut -c1`" == "8" ]; then
    sed -ie "s/^\#*shared_buffers = 4096MB/shared_buffers = 2048MB/g" /var/lib/pgsql/9.3/data/postgresql.conf
    sed -ie "s/^\#*maintenance_work_mem = 16384MB/maintenance_work_mem = 16MB/g" /var/lib/pgsql/9.3/data/postgresql.conf
    sed -ie "s/^\#*effective_cache_size = 16384MB/effective_cache_size = 2409MB/g" /var/lib/pgsql/9.3/data/postgresql.conf
  fi
fi

## we always than the most recent version of these files

su - postgres -c "cp /var/lib/pgsql/basebackup.sh /var/lib/pgsql/9.3/data/basebackup.sh"
su - postgres -c "cp /var/lib/pgsql/pgpool_remote_start /var/lib/pgsql/9.3/data/pgpool_remote_start"

###rm -rf /var/run/postgres_starting

if [ -n "$POSTGRES_NODES" ]
then 
    for server in $POSTGRES_NODES; do
    	count=` grep 'host replication postgres $server/32 trust' /var/lib/pgsql/9.3/data/pg_hba.conf | wc -l`
		if [ $count -eq 0 ]
		then 
        	echo "host replication postgres $server/32 trust" >> /var/lib/pgsql/9.3/data/pg_hba.conf
        fi
        count=` grep 'host all pgpool_checker $server/32 trust' /var/lib/pgsql/9.3/data/pg_hba.conf | wc -l`
		if [ $count -eq 0 ]
		then 
        	echo "host all pgpool_checker $server/32 trust" >> /var/lib/pgsql/9.3/data/pg_hba.conf
        fi
    done
fi

if [ -n "$PGPOOL_NODES" ] 
then 
    for server in $PGPOOL_NODES; do
	count=` grep 'host all all            $server/32	trust' /var/lib/pgsql/9.3/data/pg_hba.conf | wc -l`
	if [ $count -eq 0 ]
	then    
        	echo "host all all            $server/32	trust" >> /var/lib/pgsql/9.3/data/pg_hba.conf
        fi
        
        count=` grep 'host all pgpool_checker $server/32	trust' /var/lib/pgsql/9.3/data/pg_hba.conf | wc -l`
	if [ $count -eq 0 ]
	then  
       		echo "host all pgpool_checker $server/32	trust" >> /var/lib/pgsql/9.3/data/pg_hba.conf
	fi
    done
fi
count=`grep 'host all postgres 0.0.0.0/0 md5' /var/lib/pgsql/9.3/data/pg_hba.conf | wc -l`
if [ $count -eq 0 ]
then
    echo "host all postgres 0.0.0.0/0 md5" >> /var/lib/pgsql/9.3/data/pg_hba.conf
fi

count=`grep 'host all pgpool_checker 0.0.0.0/0 trust' /var/lib/pgsql/9.3/data/pg_hba.conf | wc -l`
if [ $count -eq 0 ]; then
  echo "host all pgpool_checker 0.0.0.0/0 trust" >> /var/lib/pgsql/9.3/data/pg_hba.conf
fi
##if [ $count -gt 0 ]
##then
##    cat /var/lib/pgsql/9.3/data/pg_hba.conf | grep -v "pgpool_checker 0.0.0.0/0 trust" > /var/lib/pgsql/9.3/data/pg_hba.conf.xxx; \cp /var/lib/pgsql/9.3/data/pg_hba.conf.xxx /var/lib/pgsql/9.3/data/pg_hba.conf; rm -f /var/lib/pgsql/9.3/data/pg_hba.conf.xxx
##fi

su - postgres -c "/usr/pgsql-9.3/bin/pg_ctl -w -D /var/lib/pgsql/9.3/data reload"

keyname=`echo $HOST_IP | cut -f2 -d: | cut -f2-4 -d.`
etcdctl -no-sync -peers ${ETCD_HOST} set /database/postgres/postgres$keyname $HOST_IP

##
## if a master is found, we need to wait for pg_hba.conf to be updated on master
##

if [ $MASTERFOUND != "none" ]; then
   while [ `su - postgres -c "ssh -T $DB_USERNAME@$MASTERFOUND -p 49154 'cat /var/lib/pgsql/9.3/data/pg_hba.conf | grep "$HOST_IP" | grep repl | wc -l'"` -eq 0 ]; do
    sleep 1
  done
  echo "< $date >DEBUG: startPostgres: pg_hba now has $HOST_IP on the master." >> /var/log/postgres/postgres.log
fi

## if there happens to be an artifact version of a backup_label from a failed master restore, delete that
if [ -f /var/lib/pgsql/9.3/data/backup_label ]; then 
  rm -f /var/lib/pgsql/9.3/data/backup_label
fi

 

echo "< $date >LOG: startPostgres: Starting Postgres." >> /var/log/postgres/postgres.log
su - postgres -c '/usr/pgsql-9.3/bin/postgres -D /var/lib/pgsql/9.3/data' &

#give postgres a chance to start up before creating this new user

writer=false
running=false
cnt=0
MAX_RETRIES=15

while [ $cnt -lt $MAX_RETRIES ] && [ $running == "false" ]
do
    date=`date +"%Y-%m-%d %H:%M:%S %Z"`
    echo "< $date >DEBUG: waiting for postgres to be up and running...." >> /var/log/postgres/postgres.log 
    sleep 2 
    cnt=$((cnt+1))
    if [ `ps -ef | grep 'postgres: logger process' | wc -l` -gt 1 ]; then
	running=true
    fi
done

if [ $running == "true" ]; then 
    # if postgres is NOT the slave
    if [ `ps -ef | grep 'wal receiver' | grep -v grep | wc -l` -lt 1 ]; then
	    su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/create_pgpool_user.sql"
    	su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/alter_postgres_user.sql"
    	echo "\q" > /tmp/quit
    	su - postgres -c "/usr/pgsql-9.3/bin/psql -U pgpool_checker -d CROSDB -h dbaasCluster -p 9999 < /tmp/quit" 
    	status=$?
    	if [ $status != 0 ]; then
  			su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/create_cros_database_and_roles.sql"
  		fi    
    fi
fi

rm -f /var/run/postgres_starting
