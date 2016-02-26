#!/bin/bash

touch /tmp/pgpool_starting

export PGPOOLADMIN_USERNAME=postgres
export PGPOOL_USERNAME=root
export DB_USERNAME=postgres

openssl rsautl -inkey /key.txt -decrypt </output.bin
export DB_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f1`
export PGPOOL_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f2`
export PGPOOLADMIN_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f3`

##if we are running this we need to make sure all old run artifacts are deleted
rm -f /var/run/pgpool/*
rm -f /var/run/pgpool/.s*

if [ ! -f /usr/local/etc/pool_passwd ]; then
	cp -r /usr/local/conf/* /usr/local/etc
fi
if [ "`cat /usr/local/etc/pgpool.conf | grep num_init_children | wc -l`" == "0" ]; then
  cp /usr/local/conf/pgpool.conf /usr/local/etc
fi
if [ "`cat /usr/local/etc/pool_passwd | grep md5 | wc -l`" == "0" ]; then
  cp /usr/local/conf/pool_passwd /usr/local/etc
fi
if [ -f "/usr/local/etc/pool_passwd" ]; then
  cp /usr/local/conf/pool_passwd* /usr/local/etc
fi

if [ "`cat /usr/local/etc/pool_passwd | grep -i 'crosadmin' | wc -l`" == "0" ]; then
  cp /usr/local/conf/pool_passwd* /usr/local/etc
fi

if [ "`cat /usr/local/etc/pool_hba.conf | grep -i 'crosadmin' | wc -l`" == "0" ]; then
  cp /usr/local/conf/pool_hba.conf /usr/local/etc
fi

##We will now use keepalived so watchdog should ALWAYS be turned off in pgpool configuration
sed -ie "s/^use_watchdog = on/use_watchdog = off/g" /usr/local/etc/pgpool.conf

#new base number of connections is 1000
sed -ie "s/^num_init_children = 500/num_init_children = 1000/g" /usr/local/etc/pgpool.conf

sed -ie "s/^pool_passwd = .*/pool_passwd = 'pool_passwd'/g" /usr/local/etc/pgpool.conf

sed -ie "s/\$HOST_IP/`echo $HOST_IP`/g" /usr/local/etc/pgpool.conf
sed -ie "s/\$PG_VIRTUAL_IP/`echo $PG_VIRTUAL_IP`/g" /usr/local/etc/pgpool.conf

echo $HOST_IP > /var/www/html/myip

sed -ie  '/backend_hostname/,+4d'  /usr/local/etc/pgpool.conf
sed -ie  '/^other_pgpool_hostname/,+5d' /usr/local/etc/pgpool.conf
sed -ie  '/^delegate_IP = /d' /usr/local/etc/pgpool.conf

sed -ie  '/host all all/d' /usr/local/etc/pool_hba.conf
sed -ie  '/host all postgres/d' /usr/local/etc/pool_hba.conf
sed -ie  '/pgpool_checker/d' /usr/local/etc/pool_hba.conf

date=`date +"%Y-%m-%d %H:%M:%S"`
echo "$date DEBUG: startPgpool.sh: just deleted all from startPgpool.sh." >> /var/log/pgpool/pgpool.log

quote="'"

sed -ie "s/\$HOST_IP/`echo $HOST_IP`/g" /usr/local/etc/pgpool.conf

param="delegate_IP ="
server=`echo $PG_VIRTUAL_IP`
echo $param $quote$server$quote >> /usr/local/etc/pgpool.conf

# check that confd is up by checking its status file... if not there loop
while [ ! -f /tmp/pg.conf ]; do
  sleep 5
done

PGPOOL_NODES=`cat /tmp/pg.conf | grep -oP '(?<=database/pgpool/pgpool).*?(?=}|$)' |cut -d" " -f2`
if [ -n "$PGPOOL_NODES" ]
then 
    count=0
    for server in $PGPOOL_NODES; do
##        echo "host all all $server/32 trust" >> /usr/local/etc/pool_hba.conf
##        echo "host all pgpool_checker $server/32	trust" >> /usr/local/etc/pool_hba.conf
        if [ $HOST_IP != $server ]
        then
            param="other_pgpool_hostname$count ="
            server=`echo $server`
            echo $param $quote$server$quote >> /usr/local/etc/pgpool.conf
            echo "other_pgpool_port$count = 9999" >> /usr/local/etc/pgpool.conf
            echo "other_wd_port$count = 9694" >> /usr/local/etc/pgpool.conf
            param="heartbeat_destination$count ="
            echo $param $quote$server$quote >> /usr/local/etc/pgpool.conf
            echo "heartbeat_destination_port$count = 9694" >> /usr/local/etc/pgpool.conf
            echo "heartbeat_device$count = 'eth0'" >> /usr/local/etc/pgpool.conf

	    echo "$date DEBUG: startPgpool.sh: added configuration entry for pgpool $server." >> /var/log/pgpool/pgpool.log
            count=$((count+1))

#	    sed -ie "s/^use_watchdog = off/use_watchdog = on/g" /usr/local/etc/pgpool.conf

        fi
    done

##    echo "$date DEBUG: startPgpool.sh: check if all the other pgpool servers are reachable." >> /var/log/pgpool/pgpool.log
##    # Check if this pgpool is replacing a dead one. If so, remove that one's key in etcd
##    # But note that we always want to have 2 pgpools, even if one is dead. Just not more than one
##    if [ $count -gt 1 ]
##    then
##        for server in $PGPOOL_NODES; do
##        if [ $HOST_IP != $server ]
##        then
##	    if [ $count -gt 1 ] 
##            then
##            	ping -c1 $server > /dev/null 2>&1
##            	if [ `echo $?` -ne 0 ]
##            	then
##		    keyname=`echo $server | cut -f2 -d: | cut -f2-4 -d.`
##	    	    echo "$date DEBUG: startPgpool.sh: removing etcd key for unreachable pgpool server $server." >> /var/log/pgpool/pgpool.log
##		    etcdctl -no-sync -peers ${ETCD_HOST} rm /database/pgpool/pgpool$keyname
##            	    count=$((count-1))
##            	fi
##            fi
##        fi
##        done
##
##    fi
fi

# Add our new POSTGRES nodes
POSTGRES_NODES=`cat /tmp/pg.conf | grep -oP '(?<=database/postgres/postgres).*?(?=}|$)' |cut -d" " -f2`
if [ -n "$POSTGRES_NODES" ]
then 
    count=0
    for server in $POSTGRES_NODES; do
##        echo "host all all $server/32 trust" >> /usr/local/etc/pool_hba.conf
##        echo "host all pgpool_checker $server/32	trust" >> /usr/local/etc/pool_hba.conf
        param="backend_hostname$count ="
        server=`echo $server`
        echo $param $quote$server$quote >> /usr/local/etc/pgpool.conf
        echo "backend_port$count = 5432" >> /usr/local/etc/pgpool.conf
        echo "backend_weight$count = 1" >> /usr/local/etc/pgpool.conf
        echo "backend_data_directory$count = '/var/lib/pgsql/9.3/data' " >> /usr/local/etc/pgpool.conf
        echo "backend_flag$count= 'ALLOW_TO_FAILOVER' " >> /usr/local/etc/pgpool.conf

	echo "$date DEBUG: startPgpool.sh: added configuration entry for postgres $server." >> /var/log/pgpool/pgpool.log
        count=$((count+1))
    done
fi
echo "host all postgres 0.0.0.0/0 md5" >> /usr/local/etc/pool_hba.conf
echo "host all pgpool_checker 0.0.0.0/0 trust" >> /usr/local/etc/pool_hba.conf
####echo "host all pgpool_checker ::1/0 trust" >> /usr/local/etc/pool_hba.conf



### Open ssh tunnels

## if ssh keys don't exist for root or apache, generate them
if [ ! -f /root/.ssh/id_rsa ]; then
   echo "Warning: root SSH keys not generated.  Generating..."
  /var/www/html/keygen.expect /root/.ssh
fi
if [ ! -f /var/www/.ssh/id_rsa ]; then
  echo "Warning: apache SSH keys not generated.  Generating..."
  su -s /bin/bash apache -c "/var/www/html/keygen.expect /var/www/.ssh"
fi

##Remove below -- no tunnel needed to fldengr

## create connection to postgres nodes

if [ -n "$POSTGRES_NODES" ]
then 
    for server in $POSTGRES_NODES; do
        ping -c1 $server > /dev/null 2>&1
        if [ `echo $?` -eq 0 ]
        then
            su -s /bin/bash apache -c "/var/www/html/dbnode.discover.sh $HOST_IP $server $DB_USERNAME $DB_PASSWORD"
        fi
    done
fi

if [ ! -f /var/log/pgpool/pgpool.log ]; then
  touch /var/log/pgpool/pgpool.log
fi

rm -rf /tmp/pgpool_starting

pgpool -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf -n -D $DEBUG1 2>&1 | /usr/sbin/rotatelogs -l -f /var/log/pgpool/pgpool.log.%A 20480 &

