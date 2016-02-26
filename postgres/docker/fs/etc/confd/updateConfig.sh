export PGPOOLADMIN_USERNAME=postgres
export PGPOOL_USERNAME=root
export DB_USERNAME=postgres

openssl rsautl -inkey /key.txt -decrypt </output.bin
export DB_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f1`
export PGPOOL_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f2`
export PGPOOLADMIN_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f3`
date=`date +"%Y-%m-%d %H:%M:%S %Z"`

while [ -f /var/run/postgres_starting ]
do
    date=`date +"%Y-%m-%d %H:%M:%S %Z"`
    echo "< $date >DEBUG: updateConfig: waiting for startPostgres to complete...." >> /var/log/postgres/postgres.log 
    sleep 30
done

if [ `ps -ef | grep 'postgres: logger process' | wc -l` -gt 1 ]; then 
    # if postgres is NOT the slave
  	if [ `ps -ef | grep 'wal receiver' | grep -v grep | wc -l` -lt 1 ]; then
		su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/create_pgpool_user.sql"
   		su - postgres -c "/usr/pgsql-9.3/bin/psql -f /var/lib/pgsql/alter_postgres_user.sql"
   	fi
fi

echo "< $date >DEBUG: updateConfig: getting newest values for pg_hba.conf file." >> /var/log/postgres/postgres.log 
PGPOOL_NODES=`cat /tmp/postgres.conf | grep -oP '(?<=database/pgpool/pgpool).*?(?=}|$)' |cut -d" " -f2`
POSTGRES_NODES=`cat /tmp/postgres.conf | grep -oP '(?<=database/postgres/postgres).*?(?=}|$)' |cut -d" " -f2`
restart_needed=false

sed -ie  '/host all all/d' /var/lib/pgsql/9.3/data/pg_hba.conf
sed -ie  '/postgres/d' /var/lib/pgsql/9.3/data/pg_hba.conf
sed -ie  '/pgpool_checker/d' /var/lib/pgsql/9.3/data/pg_hba.conf

OTHERDBNODEFOUND=0
MASTERFOUND="none"
if [ ! -f /var/lib/pgsql/9.3/data/postgresql.conf ]; then
  echo "< $date >LOG: updateConfig: Postgres must be installed before updating pg_hba.conf." >> /var/log/postgres/postgres.log 
else
  su - postgres -c 'cp /var/lib/pgsql/pg_hba.conf /var/lib/pgsql/9.3/data/pg_hba.conf'
  if [ -n "$PGPOOL_NODES" ] 
  then 
	# Add our PGPOOL nodes
	for server in $PGPOOL_NODES; do
           echo "host all all             $server/32	trust" >> /var/lib/pgsql/9.3/data/pg_hba.conf
           echo "host all pgpool_checker $server/32	trust" >> /var/lib/pgsql/9.3/data/pg_hba.conf
           echo "< $date >DEBUG: updateConfig: adding pgpool host for server $server." >> /var/log/postgres/postgres.log 

	    ping -c1 $server > /dev/null 2>&1
	    if [ `echo $?` -eq 0 ]
	    then
  	        su - postgres -c "/var/lib/pgsql/pgpool.discover.sh $HOST_IP $server $PGPOOL_USERNAME $PGPOOL_PASSWORD"
	    fi
	done

  fi
  if [ -n "$POSTGRES_NODES" ]
  then 
	# Add our POSTGRES nodes
	for server in $POSTGRES_NODES; do
           echo "host replication postgres   $server/32	trust" >> /var/lib/pgsql/9.3/data/pg_hba.conf
           echo "host all pgpool_checker $server/32	trust" >> /var/lib/pgsql/9.3/data/pg_hba.conf

           date=`date +"%Y-%m-%d %H:%M:%S %Z"`
           echo "< $date >DEBUG: updateConfig: adding postgres host for server $server." >> /var/log/postgres/postgres.log 

           if [ $HOST_IP != $server ]
           then
  	       echo "< $date >DEBUG: updateConfig: $HOST_IP and $server are unequal, so pinging $server." >> /var/log/postgres/postgres.log 
	       ping -c1 $server > /dev/null 2>&1
	       if [ `echo $?` -eq 0 ]
	       then
                   su - postgres -c "/var/lib/pgsql/dbnode.discover.sh $HOST_IP $server $DB_USERNAME $DB_PASSWORD"
  	           CAN_I_CONNECT=`su - postgres -c "ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' $DB_USERNAME@$server -p 49154 'echo 2>&1' && echo SSH__OK || echo SSH_NOK"`
  	           if [ $CAN_I_CONNECT == "SSH__OK" ]; then
    	               OTHERDBNODEFOUND=1
  	               date=`date +"%Y-%m-%d %H:%M:%S %Z"`
  	               echo "< $date >DEBUG: updateConfig: connecting ok to $server." >> /var/log/postgres/postgres.log 
    	               if [ `su - postgres -c "ssh -T $DB_USERNAME@$server -p 49154 'head -1 /var/lib/pgsql/9.3/data/postgresql.conf 2>/dev/null | wc -l'"` -eq 1 ]; then
  	                   echo "< $date >DEBUG: updateConfig: searching for postgresql.conf indicated it was there" >> /var/log/postgres/postgres.log 
      	                   if [ `su - postgres -c "ssh -T $DB_USERNAME@$server -p 49154 'head -1 /var/lib/pgsql/9.3/data/recovery.conf 2>/dev/null | wc -l'"` -eq 0 ]; then
  	                       echo "< $date >DEBUG: updateConfig: searching for recovery.conf indicated it was not there" >> /var/log/postgres/postgres.log
                               TESTPSQL=0
                               PSQLCHECKS=0
                               while [ $TESTPSQL -eq 0 ]; do
                                 date=`date +"%Y-%m-%d %H:%M:%S %Z"`
                                 TESTPSQL=`psql -U pgpool_checker -h $server -p 5432 -d postgres -c "select 'xyz'" | grep xyz | grep -v grep | wc -l`
                                 if [ $TESTPSQL -eq 1 ]; then
                                   echo "< $date >DEBUG: updateConfig: connection to the database node $server was successful " >> /var/log/postgres/postgres.log
                                   MASTERFOUND=$server
                                 fi
                                 echo "< $date >DEBUG: updateConfig: connection to the database node $server was unsuccessful " >> /var/log/postgres/postgres.log
                                 PSQLCHECKS=`expr $PSQLCHECKS + 1`
                                 if [ $PSQLCHECKS -gt 12 ]; then
                                   TESTPSQL=1
                                   if [ "$MASTERFOUND" == "none" ]; then
                                     echo "< $date >DEBUG: updateConfig: psql connection to the database node $server was unsuccessful after 60 seconds.  This is not a working master... Proceeding." >> /var/log/postgres/postgres.log
                                   fi
                                 fi
                                 if [ $TESTPSQL -eq 0 ]; then
                                   sleep 5
                                 fi
                               done
                           fi
                       fi
                   fi
               fi
           fi
	done
  fi

count=`grep 'host all postgres 0.0.0.0/0 md5' /var/lib/pgsql/9.3/data/pg_hba.conf | wc -l`
if [ $count -eq 0 ]
then
    echo "host all postgres 0.0.0.0/0 md5" >> /var/lib/pgsql/9.3/data/pg_hba.conf
fi

count=`grep 'host all pgpool_checker 0.0.0.0/0 trust' /var/lib/pgsql/9.3/data/pg_hba.conf | wc -l`
if [ $count -eq 0 ]
then
    echo "host all pgpool_checker 0.0.0.0/0 trust" >> /var/lib/pgsql/9.3/data/pg_hba.conf
fi

date=`date +"%Y-%m-%d %H:%M:%S %Z"`
echo "< $date >DEBUG: updateConfig: Found Master Postgres = $MASTERFOUND." >> /var/log/postgres/postgres.log

  ##
  ## if I found a master other than myself, I may need to issue a recovery
  ##
  if [ $MASTERFOUND != "none" ]; then
    if [ -f /var/lib/pgsql/9.3/data/recovery.conf ]; then
      if [ `cat /var/lib/pgsql/9.3/data/recovery.conf | grep $MASTERFOUND | wc -l 2>/dev/null` -eq 1 ]; then
        echo "< $date >DEBUG: updateConfig: Found an existing recovery.conf locally. Already matches $MASTERFOUND" >> /var/log/postgres/postgres.log 
        ## do we have a running postgres?
        if [ `ps -ef | grep postgres | grep -v "grep" | grep -v "KeepAlive" | wc -l` -ne 0 ]; then
          ## do we have a postgres wal receiver?
          if [ `ps -ef | grep "postgres: wal receiver process" | grep "streaming" | grep -v "grep" | wc -l` -eq 0 ]; then
            ## postgres is not replicating... we need to reboot!
            echo "< $date >DEBUG: updateConfig: Postgres is running locally, but is not replicating properly.  Issuing a soft restart of postgres." >> /var/log/postgres/postgres.log
            restart_needed=true
          else
            echo "< $date >DEBUG: updateConfig: Postgres is running locally, and is replicating properly.  OK." >> /var/log/postgres/postgres.log
          fi
        else
          echo "< $date >DEBUG: updateConfig: Postgres is not running locally, but I am supposed to be a standby.  Issuing fresh base backup." >> /var/log/postgres/postgres.log
          su - postgres -c "ssh -T $DB_USERNAME@$MASTERFOUND -p 49154 '/var/lib/pgsql/9.3/data/basebackup.sh /var/lib/pgsql/9.3/data $HOST_IP /var/lib/pgsql/9.3/data $DB_USERNAME $DB_PASSWORD'"
          restart_needed=true
        fi
      else
        echo "< $date >DEBUG: updateConfig: Found an existing recovery.conf locally. Mismatch on master found, updating recovery.conf and issuing fresh base backup." >> /var/log/postgres/postgres.log 
        su - postgres -c "ssh -T $DB_USERNAME@$MASTERFOUND -p 49154 '/var/lib/pgsql/9.3/data/basebackup.sh /var/lib/pgsql/9.3/data $HOST_IP /var/lib/pgsql/9.3/data $DB_USERNAME $DB_PASSWORD'"
        restart_needed=true
      fi
    else
    ## what if we find another master but have recovery.done locally?  We may want to reboot...
      if [ "`[ -f /var/lib/pgsql/9.3/data/recovery.done ] && echo 'Found' || echo 'Not found'`" == "Found" ]; then
        echo "< $date >DEBUG: updateConfig: Found existing recovery.done locally.  Checking to see who is real master..." >> /var/log/postgres/postgres.log
        if [ `su - postgres -c "ssh -T $DB_USERNAME@$MASTERFOUND -p 49154 '[ -f /var/lib/pgsql/9.3/data/recovery.done ] && echo 'Found' || echo 'Not found''"` == "Found" ]; then
          ## Found remote recovery.done and local recovery.done. Check dbaascluster to find original master
          echo "< $date >DEBUG: updateConfig: Found remote recovery.done.  Checking dbaascluster for master reference..." /var/log/postgres/postgres.log
          HEALTHYPRIMARY=`psql -U pgpool_checker -h dbaascluster -p 9999 -d postgres -c "show pool_nodes" | grep primary | grep '| 2' | wc -l`
          if [ $HEALTHYPRIMARY -eq 1 ]; then
            ## one current master was found in dbaascluster.  This is live!  Reboot the old standby only!
            ORIGINAL_PRIMARY=`psql -U pgpool_checker -h dbaascluster -p 9999 -d postgres -c "show pool_nodes" | grep primary | grep '| 2' | awk '{ print $3 }'` 
            if [ "${ORIGINAL_PRIMARY}" == "${HOST_IP}" ]; then
              ## we are the original primary!  Wait for the standby(s) to reboot and sync with me.
              echo "< $date >DEBUG: updateConfig: I am the original primary node. Mismatched standby will reboot automatically." /var/log/postgres/postgres.log
            else
              ## we are an old standby that incorrectly became master!  Reboot to sync with real master.
              echo "< $date >DEBUG: updateConfig: I am not the original primary node. I must be a mismatched standby.  I will reboot automatically." /var/log/postgres/postgres.log
              touch /tmp/rebootnode
            fi
          else
            ## Couldn't get primary info from dbaascluster, or it showed multiple masters.
            echo "< $date >DEBUG: updateConfig: Could not determine master information from dbaascluster.  Checking timestamps of recovery.done......" /var/log/postgres/postgres.log
            DATE1=`stat /var/lib/pgsql/9.3/data/recovery.done | grep Modify | cut -c 9-37`
            DATE1F=`date -d "${DATE1}" +%Y%m%d%H%M%S`
            DATE2=`su - postgres -c "ssh -T $DB_USERNAME@$MASTERFOUND -p 49154 'stat /var/lib/pgsql/9.3/data/recovery.done | grep Modify | cut -c 9-37'"`
            DATE2F=`date -d "${DATE2}" +%Y%m%d%H%M%S`
            if [ $DATE1F -eq $DATE2F ]; then
            ## We actually have a tie on MM-DD-YYYY HH:MM:SS.  Headed to microsecond tiebreaker!
              DATE1S=`date -d "${DATE2}" +%S%N`
              DATE1S=`date -d "${DATE2}" +%S%N`
              echo "< $date >DEBUG: updateConfig: Local recovery.done  : "$DATE1" : "$DATE1F" : "$DATE1S >> /var/log/postgres/postgres.log
              echo "< $date >DEBUG: updateConfig: Remote recovery.done : "$DATE2" : "$DATE2F" : "$DATE2S >> /var/log/postgres/postgres.log
              if [ $DATE2S -gt $DATE1S ]; then
                echo "< $date >DEBUG: updateConfig: Remote recovery.done is newer than local.  Issuing a reboot." >> /var/log/postgres/postgres.log
                touch /tmp/rebootnode
              else
                echo "< $date >DEBUG: updateConfig: Local recovery.done is newer than remote, this is the real master.  Mismatched standbys will reboot automatically." >> /var/log/postgres/postgres.log
              fi
            else
              echo "< $date >DEBUG: updateConfig: Local recovery.done  : "$DATE1" : "$DATE1F >> /var/log/postgres/postgres.log
              echo "< $date >DEBUG: updateConfig: Remote recovery.done : "$DATE2" : "$DATE2F >> /var/log/postgres/postgres.log
              if [ $DATE2F -gt $DATE1F ]; then
                echo "< $date >DEBUG: updateConfig: Remote recovery.done is newer than local.  Issuing a reboot." >> /var/log/postgres/postgres.log
                touch /tmp/rebootnode
              else
                echo "< $date >DEBUG: updateConfig: Local recovery.done is newer than remote, this is the real master.  Mismatched standbys will reboot automatically." >> /var/log/postgres/postgres.log
              fi
            fi
          fi
        else
          echo "< $date >ERROR: updateConfig: Remote recovery.done not found but still detected as master.  Check state of DB cluster!" >> /var/log/postgres/postgres.log
        fi
      else
        echo "< $date >DEBUG: updateConfig: No recovery.conf file found locally. I am the master postgres." >> /var/log/postgres/postgres.log
      fi
    fi
  fi
  if [ $restart_needed == "true" ]; then
        echo "< $date >DEBUG: updateConfig: Postgres restart needed, so restarting..." >> /var/log/postgres/postgres.log 
        su - postgres -c '/usr/pgsql-9.3/bin/pg_ctl restart -m i -D /var/lib/pgsql/9.3/data'
#####
  else
        echo "< $date >DEBUG: updateConfig: Attempt postgres reload..." >> /var/log/postgres/postgres.log 
        su - postgres -c "/usr/pgsql-9.3/bin/pg_ctl -w -D /var/lib/pgsql/9.3/data reload"
  fi
fi
