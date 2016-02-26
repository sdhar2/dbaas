export PGPOOLADMIN_USERNAME=postgres
export PGPOOL_USERNAME=root
export DB_USERNAME=postgres

openssl rsautl -inkey /key.txt -decrypt </output.bin
export DB_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f1`
export PGPOOL_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f2`
export PGPOOLADMIN_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f3`
date=`date +"%Y-%m-%d %H:%M:%S"`
echo "$date DEBUG: updateConfig.sh: getting newest values for pg.conf file " >> /var/log/pgpool/pgpool.log

while [ -f /tmp/pgpool_starting ]
do
	date=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$date DEBUG: updateConfig: waiting for startPgpool to complete...." >> /var/log/pgpool/pgpool.log 
    sleep 30
done

sed -ie  '/postgres/d' /usr/local/etc/pool_hba.conf
sed -ie  '/host all all/d' /usr/local/etc/pool_hba.conf
sed -ie  '/pgpool_checker/d' /usr/local/etc/pool_hba.conf

PGPOOL_NODES=`cat /tmp/pg.conf | grep -oP '(?<=database/pgpool/pgpool).*?(?=}|$)' |cut -d" " -f2`
POSTGRES_NODES=`cat /tmp/pg.conf | grep -oP '(?<=database/postgres/postgres).*?(?=}|$)' |cut -d" " -f2`
EXISTING_POSTGRES_NODES=`pcp_node_count 5 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD`

sed -ie  '/backend_hostname/,+4d'  /usr/local/etc/pgpool.conf
sed -ie  '/^other_pgpool_hostname/,+5d' /usr/local/etc/pgpool.conf
sed -ie  '/^delegate_IP = /d' /usr/local/etc/pgpool.conf
echo "$date DEBUG: updateConfig.sh: just deleted all from upateConfig.sh." >> /var/log/pgpool/pgpool.log

quote="'"

sed -ie "s/\$HOST_IP/`echo $HOST_IP`/g" /usr/local/etc/pgpool.conf

param="delegate_IP ="
server=`echo $PG_VIRTUAL_IP`
echo $param $quote$server$quote >> /usr/local/etc/pgpool.conf

restart_needed=false

PGPOOL_NODES=`cat /tmp/pg.conf | grep -oP '(?<=database/pgpool/pgpool).*?(?=}|$)' |cut -d" " -f2`
if [ -n "$PGPOOL_NODES" ] 
then 
    other_pgpool_found=false
    count=0
    # Add our new PGPOOL nodes

    for server in $PGPOOL_NODES; do
##        echo "host all all $server/32 trust" >> /usr/local/etc/pool_hba.conf
##        echo "host all pgpool_checker `echo $server`/32	trust" >> /usr/local/etc/pool_hba.conf
        echo "$date DEBUG: updateConfig.sh: there are pgpool nodes, server = $server." >> /var/log/pgpool/pgpool.log
        if [ $HOST_IP != $server ]
        then
            other_pgpool_found=true;
            param="other_pgpool_hostname$count ="
            server=`echo $server`
            echo $param $quote$server$quote >> /usr/local/etc/pgpool.conf
            echo "other_pgpool_port$count = 9999" >> /usr/local/etc/pgpool.conf
            echo "other_wd_port$count = 9694" >> /usr/local/etc/pgpool.conf
            param="heartbeat_destination$count ="
            echo $param $quote$server$quote >> /usr/local/etc/pgpool.conf
            echo "heartbeat_destination_port$count = 9694" >> /usr/local/etc/pgpool.conf
            echo "heartbeat_device$count = 'eth0'" >> /usr/local/etc/pgpool.conf
	    echo "$date DEBUG: updateConfig.sh: added configuration entry for pgpool $server." >> /var/log/pgpool/pgpool.log
            count=$((count+1))

#	    if [ `grep 'use_watchdog = off' /usr/local/etc/pgpool.conf | wc -l` -eq 1 ]
#	    then
#                restart_needed=true
# 	    fi
#           sed -ie "s/^use_watchdog = off/use_watchdog = on/g" /usr/local/etc/pgpool.conf
        else
            ## Sanity check - is pgpool running locally?
            if [ `ps -eaf | grep "pgpool" | grep -v "grep" | grep -v "pgpool_health" | grep -v " pgpool: " | grep -v rotatelogs | wc -l` -eq 0 ]
            then
               ## Welp! No pgpool running!  Clean out old connections and start pgpool!
               for pid in $(/bin/ps -ef | /bin/grep " pgpool: "| /bin/grep -v grep |  /bin/awk ""' {print $2}' ); do /bin/kill -9 $pid; done
               sleep 5
               ## clean up old port bindings if present
               if [ `find /var/run/pgpool/.s.PGSQL.9898 2>/dev/null| grep -v No | wc -l` -gt 0 ]; then
                 unlink /var/run/pgpool/.s.PGSQL.9898
               fi
               if [ `find /var/run/pgpool/.s.PGSQL.9999 2>/dev/null| grep -v No | wc -l` -gt 0 ]; then
                 unlink /var/run/pgpool/.s.PGSQL.9999
               fi             
               sleep 5
               pgpool -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf -n -D 2>&1 | /usr/sbin/rotatelogs -l -f /var/log/pgpool/pgpool.log.%A 20480 &
            fi
        fi
    done

#    if [ $other_pgpool_found == "false" ]
#    then
#       sed -ie "s/^use_watchdog = on/use_watchdog = off/g" /usr/local/etc/pgpool.conf
#    fi
fi

if [ -n "$POSTGRES_NODES" ]
then 
    # Add our new POSTGRES nodes
    count=0
    echo "$date DEBUG: updateConfig.sh: found POSTGRES NODES=$POSTGRES_NODES." >> /var/log/pgpool/pgpool.log
    for server in $POSTGRES_NODES; do
##        echo "host all all $server/32 trust" >> /usr/local/etc/pool_hba.conf
##        echo "host all pgpool_checker `echo $server`/32	trust" >> /usr/local/etc/pool_hba.conf
        param="backend_hostname$count ="
        server=`echo $server`
        echo $param $quote$server$quote >> /usr/local/etc/pgpool.conf
        echo "backend_port$count = 5432" >> /usr/local/etc/pgpool.conf
        echo "backend_weight$count = 1" >> /usr/local/etc/pgpool.conf
        echo "backend_data_directory$count = '/var/lib/pgsql/9.3/data' " >> /usr/local/etc/pgpool.conf
        echo "backend_flag$count= 'ALLOW_TO_FAILOVER' " >> /usr/local/etc/pgpool.conf

        echo "$date DEBUG: updateConfig.sh: added configuration entry for postgres $server." >> /var/log/pgpool/pgpool.log
        count=$((count+1))

	## create connection to postgres nodes
        ping -c1 $server > /dev/null 2>&1
        if [ `echo $?` -eq 0 ]
        then
            su -s /bin/bash apache -c "/var/www/html/dbnode.discover.sh $HOST_IP $server $DB_USERNAME $DB_PASSWORD"
        fi
    done
fi

echo "host all postgres 0.0.0.0/0 md5" >> /usr/local/etc/pool_hba.conf
echo "host all pgpool_checker 0.0.0.0/0 trust" >> /usr/local/etc/pool_hba.conf
if [ ${HAMode} == "HA" ]; then
        echo "host all pgpool_checker ::1/0 trust" >> /usr/local/etc/pool_hba.conf
        echo "$date DEBUG: updateConfig.sh: running in HA Mode." >> /var/log/pgpool/pgpool.log
else
        echo "$date DEBUG: updateConfig.sh: not running in HA Mode; no ::1 entry added to pool_hba.conf." >> /var/log/pgpool/pgpool.log
fi

NEWPOSTGRESNODES=$count
reload_needed=false
if [ $NEWPOSTGRESNODES -ge $EXISTING_POSTGRES_NODES ]; then
  reload_needed=true
fi
 
## if reload is true but there's no pid file, we instead need to restart
if [ "$reload_needed" == "true" ]; then
  if [ ! -f /var/run/pgpool/pgpool.pid ]; then
    restart_needed=true
    reload_needed=false
  fi
fi

pidCount=`ps -eaf | grep "pgpool" | grep -v "grep" | grep -v "pgpool_health" | grep -v " pgpool: " | grep -v "rotatelogs" | wc -l`
if [ $pidCount -eq 0 ]
then
	echo "$date LOG: updateConfig.sh: did not find a running pgpool to reload, so start pgpool.." >> /var/log/pgpool/pgpool.log
        ## clean up old port bindings if present
        if [ `find /var/run/pgpool/.s.PGSQL.9898 2>/dev/null| grep -v No | wc -l` -gt 0 ]; then
          unlink /var/run/pgpool/.s.PGSQL.9898
        fi
        if [ `find /var/run/pgpool/.s.PGSQL.9999 2>/dev/null| grep -v No | wc -l` -gt 0 ]; then
          unlink /var/run/pgpool/.s.PGSQL.9999
        fi             
        sleep 5
        pgpool -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf -n -D 2>&1 | /usr/sbin/rotatelogs -l -f /var/log/pgpool/pgpool.log.%A 20480 &
else
	if [ $restart_needed == "true" ]
	then
		echo "$date LOG: updateConfig.sh: restart needed, so restarting..." >> /var/log/pgpool/pgpool.log
        	pgpool -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf -m fast stop >> /var/log/pgpool/pgpool.log 2>&1
        	sleep 30
                # kill any possible zombie connections
                for pid in $(/bin/ps -ef | /bin/grep " pgpool: "| /bin/grep -v grep |  /bin/awk ""' {print $2}' ); do /bin/kill -9 $pid; done
                sleep 30
        	pgpool -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf -n -D 2>&1 | /usr/sbin/rotatelogs -l -f /var/log/pgpool/pgpool.log.%A 20480 &	
	else
             if [ $reload_needed == "true" ]
             then
		echo "$date LOG: updateConfig.sh: found pgpool to reload, so reloading.." >> /var/log/pgpool/pgpool.log
        	pgpool -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf reload >> /var/log/pgpool/pgpool.log 2>&1	
             else
                echo "$date LOG: updateConfig.sh: no increase in the number of postgres backends, so I am not reloading." >> /var/log/pgpool/pgpool.log
             fi
	fi
fi
echo "$date DEBUG: updateConfig.sh: delay to allow for reattaching of clients.." >> /var/log/pgpool/pgpool.log
sleep 10
## do this to prime pcp connection - this might be needed
NUMNODES=`pcp_node_count 5 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD`

## sanity check to make sure pgpool is accessible
ISPGPOOLALIVE=0
ISPGPOOLALIVECOUNTER=0
while [ $ISPGPOOLALIVE -eq 0 ]; do
  ISPGPOOLALIVE=`psql -U pgpool_checker -h $HOST_IP -p 9999 -d postgres -c "select 'xyz'" | grep xyz | grep -v grep | wc -l`
  ISPGPOOLALIVECOUNTER=`expr $ISPGPOOLALIVECOUNTER + 1`
  if [ $ISPGPOOLALIVECOUNTER -gt 6 ]; then
    ISPGPOOLALIVE=1
    ISPGPOOLALIVECOUNTER=-1
  fi
  if [ $ISPGPOOLALIVE -eq 0 ]; then
    sleep 10
  fi
done
if [ $ISPGPOOLALIVECOUNTER -eq -1 ]; then
  echo "$date INFO: updateConfig.sh: Local pgpool is inaccessible.  This may be because there are zero nodes attached." >> /var/log/pgpool/pgpool.log
  echo "$date INFO: updateConfig.sh: Will attempt to reattach all available nodes." >> /var/log/pgpool/pgpool.log
  NUMNODES=`pcp_node_count 5 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD`
  for i in $(seq 0 `expr $NUMNODES - 1`); do
    echo "$date INFO: updateConfig.sh: Attempting to reattach node $i..." >> /var/log/pgpool/pgpool.log
    pcp_attach_node 10 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD $i > /dev/null 2>&1
  done
  ## check to see if pgpool is now alive
  ISPGPOOLALIVE=`psql -U pgpool_checker -h $HOST_IP -p 9999 -d postgres -c "select 'xyz'" | grep xyz | grep -v grep | wc -l`
  if [ $ISPGPOOLALIVE -eq 1 ]; then  
    echo "$date INFO: updateConfig.sh: Attempt to reattach available nodes was successful." >> /var/log/pgpool/pgpool.log 
    PRIMARY=`psql -U pgpool_checker -h $HOST_IP -p 9999 -d postgres -c "show pool_nodes" | grep primary | awk '{ print $3 }'`
    if [ -n "$PRIMARY" ]; then
      echo "$date INFO: updateConfig.sh: Primary postgres node is $PRIMARY." >> /var/log/pgpool/pgpool.log
      exit 0
    else
      echo "$date ERROR: updateConfig.sh: Pgpool accessible on reattach, but attempt to reach primary Postgres unsuccessful.  Exiting." >> /var/log/pgpool/pgpool.log
      exit 1
    fi
  else
    echo "$date LOG: updateConfig.sh: Pgpool inaccessible and attempt to reattach available nodes was unsuccessful.  Will try a reload." >> /var/log/pgpool/pgpool.log
    pgpool -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf reload >> /var/log/pgpool/pgpool.log 2>&1
    sleep 5
    echo "$date LOG: updateConfig.sh: Reload complete.  One last try to refresh nodes." >> /var/log/pgpool/pgpool.log
  fi
fi

# if I am here it means I could connect to the local pgpool to get pool_node
# use show pool_nodes to get accurate node information
FOUNDNODEINFO=0
FOUNDNODEINFOCOUNTER=0
while [ $FOUNDNODEINFO -eq 0 ]; do
  psql -U pgpool_checker -h $HOST_IP -p 9999 -d postgres -c "show pool_nodes" > /tmp/primarydbnode.$$
  FOUNDNODEINFO=`cat /tmp/primarydbnode.$$ | grep lb_weight | wc -l`
  FOUNDNODEINFOCOUNTER=`expr $FOUNDNODEINFOCOUNTER + 1`
  if [ $FOUNDNODEINFOCOUNTER -gt 6 ]; then
    FOUNDNODEINFO=1
  fi
  if [ $FOUNDNODEINFO -eq 0 ]; then
    sleep 5
  fi
done

##echo "$date DEBUG: updateConfig.sh:  pool_node info: " >> /var/log/pgpool/pgpool.log
##cat /tmp/primarydbnode.$$ >> /var/log/pgpool/pgpool.log

# audit pool_nodes and make sure there is 1 postgres entry per entry
# if there isn't, reboot pgpool

for server in $POSTGRES_NODES; do
  FOUNDPOSTGRESENTRY=`cat /tmp/primarydbnode.$$ | grep $server | wc -l`
  if [ $FOUNDPOSTGRESENTRY -eq 0 ]; then
    ## pgpool isn't detecting nodes correctly.  Restart pgpool.
    echo "$date INFO: updateConfig.sh: $server not found in pgpool cluster definition.  Restart needed, so restarting..." >> /var/log/pgpool/pgpool.log
    pgpool -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf -m fast stop >> /var/log/pgpool/pgpool.log 2>&1
    sleep 10
    # kill any possible zombie connections
    for pid in $(/bin/ps -ef | /bin/grep " pgpool: " | /bin/grep -v grep |  /bin/awk ""' {print $2}' ); do /bin/kill -9 $pid; done
    sleep 10
    pgpool -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf -n -D 2>&1 | /usr/sbin/rotatelogs -l -f /var/log/pgpool/pgpool.log.%A 20480 &
    sleep 15
    ## now that we've rebooted, remake a good show pool_nodes to check for the node reattach
    FOUNDNODEINFO=0
    FOUNDNODEINFOCOUNTER=0
    while [ $FOUNDNODEINFO -eq 0 ]; do
      psql -U pgpool_checker -h $HOST_IP -p 9999 -d postgres -c "show pool_nodes" > /tmp/primarydbnode.$$
      FOUNDNODEINFO=`cat /tmp/primarydbnode.$$ | grep lb_weight | wc -l`
      FOUNDNODEINFOCOUNTER=`expr $FOUNDNODEINFOCOUNTER + 1`
      if [ $FOUNDNODEINFOCOUNTER -gt 6 ]; then
        FOUNDNODEINFO=1
      fi
      if [ $FOUNDNODEINFO -eq 0 ]; then
        sleep 5
      fi
    done
    ## one last check... do we now find the correct postgres entry?
    NEWFOUNDPOSTGRESENTRY=`cat /tmp/primarydbnode.$$ | grep $server | wc -l`
    if [ $NEWFOUNDPOSTGRESENTRY -eq 0 ]; then
      ## nope... still a problem.  Exit.
      echo "$date ERROR: updateConfig.sh: Even after reboot, pgpool didn't detect $server correctly.  Exiting." >> /var/log/pgpool/pgpool.log
      exit 1
    else
      ## we are fixed!  Report status and continue to node connection check.
      echo "$date INFO: updateConfig.sh: After reboot, pgpool detected $server correctly.  Continuing to node connection check..." >> /var/log/pgpool/pgpool.log
    fi
  fi 
done

# check for any nodes that need reattaching
cat /tmp/primarydbnode.$$ | grep '| 3' > /tmp/dbnodeerr
FOUNDDISCONNECT=`cat /tmp/dbnodeerr | wc -l`
if [ $FOUNDDISCONNECT -gt 0 ]; then
  ## we found one or more unattached nodes.  Attempting to reattach them.
  echo "$date LOG: updateConfig.sh: Found that there were unattached nodes.  Attempting to reattach them." >> /var/log/pgpool/pgpool.log
  for i in $POSTGRES_NODES; do
    ETCDMATCH=`cat /tmp/dbnodeerr | grep $i | wc -l`
    if [ $ETCDMATCH -gt 0 ]; then
      echo "$date LOG: updateConfig.sh: Postgres node $i is not attached.  Attempting to reattach it." >> /var/log/pgpool/pgpool.log 
      DBNODE=`cat /tmp/dbnodeerr | grep '| 3' | grep $i | head -1 | awk '{ print $1 }'`
      AMILIVE=0
      AMILIVECOUNTER=0
      while [ $AMILIVE -eq 0 ]; do
        date=`date +"%Y-%m-%d %H:%M:%S"`
        AMILIVE=`psql -U pgpool_checker -h $i -p 5432 -d postgres -c "select 'xyz'" | grep xyz | grep -v grep | wc -l`
        AMILIVECOUNTER=`expr $AMILIVECOUNTER + 1`
        if [ $AMILIVECOUNTER -gt 480 ]; then
          AMILIVE=1
        fi
        echo "$date LOG: updateConfig.sh: postgres node $DBNODE connection check iteration "$AMILIVECOUNTER" = "$AMILIVE >> /var/log/pgpool/pgpool.log
        sleep 15
      done
      pcp_attach_node 10 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD $DBNODE > /dev/null 2>&1
      echo "$date LOG: updateConfig.sh: attempt to attach node $DBNODE complete." >> /var/log/pgpool/pgpool.log
      rm -f /tmp/pgpoolattach      
    fi
  done
fi

##for i in $(seq 0 `expr $NUMNODES - 1`); do
##   pcp_node_info 5 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD $i > /tmp/primarydbnode.$$
##   echo "$date DEBUG: updateConfig.sh: node $i information: "`cat /tmp/primarydbnode.$$` >> /var/log/pgpool/pgpool.log
##   DBNODE=`awk '{ print $1 }' /tmp/primarydbnode.$$`
##   state=`awk '{ print $3 }' /tmp/primarydbnode.$$`
##   if [ $state -eq 3 ]
##   then
##        echo "$date LOG: updateConfig.sh: Checking etcd status for postgres node $DBNODE." >> /var/log/pgpool/pgpool.log
##        POSTGRES_NODES=`cat /tmp/pg.conf | grep -oP '(?<=database/postgres/postgres).*?(?=}|$)' |cut -d" " -f2`
##        if [ `echo $POSTGRES_NODES | grep $DBNODE | wc -l` -eq 1 ]; then  
##	  echo "$date LOG: updateConfig.sh: Found in etcd.  Reattaching postgres node $DBNODE." >> /var/log/pgpool/pgpool.log
##	  AMILIVE=0
##          AMILIVECOUNTER=0
##          while [ $AMILIVE -eq 0 ]; do
##	     date=`date +"%Y-%m-%d %H:%M:%S"`
##             AMILIVE=`psql -U pgpool_checker -h $DBNODE -p 5432 -d postgres -c "select 'xyz'" | grep xyz | grep -v grep | wc -l`
##             AMILIVECOUNTER=`expr $AMILIVECOUNTER + 1`
##             if [ $AMILIVECOUNTER -gt 480 ]; then
##                AMILIVE=1
##             fi
##	     echo "$date LOG: updateConfig.sh: postgres node $DBNODE connection check iteration "$AMILIVECOUNTER" = "$AMILIVE >> /var/log/pgpool/pgpool.log
##             sleep 15            
##         done
##	  pcp_attach_node 10 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD $i > /tmp/pgpoolattach 2>&1
##          echo "$date LOG: updateConfig.sh: attach output: "`cat /tmp/pgpoolattach` >> /var/log/pgpool/pgpool.log
##          rm -f /tmp/pgpoolattach
##	fi
##   fi
##done
rm -f /tmp/dbnodeerr
rm -f /tmp/primarydbnode.$$
