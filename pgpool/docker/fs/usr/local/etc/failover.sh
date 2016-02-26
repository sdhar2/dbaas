#!/bin/sh -x
# Execute command by failover.
# special values:  %d = node id
#                  %h = host name
#                  %p = port number
#                  %D = database cluster path
#                  %m = new master node id
#                  %M = old master node id
#                  %H = new master node host name
#                  %P = old primary node id
#                  %% = '%' character
failed_node_id=$1
failed_host_name=$2
failed_port=$3
failed_db_cluster=$4
new_master_id=$5
old_master_id=$6
new_master_host_name=$7
old_primary_node_id=$8
##trigger=/var/lib/pgsql/9.3/data/trigger
HOST_IP=`cat /var/www/html/myip`
export DB_USERNAME=postgres
openssl rsautl -inkey /key.txt -decrypt </output.bin
export DB_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f1`

echo "failover triggered at "`date` >> /tmp/failoverlog
echo "failed node id "$failed_node_id >> /tmp/failoverlog
echo "failed host name "$failed_host_name"
echo "old primary node id "$old_primary_node_id >> /tmp/failoverlog
echo "new master host name "$new_master_host_name"
echo "whoami: "`whoami` >> /tmp/failoverlog
####
## one last check of tunnel just to make sure it's healthy
####
su -s /bin/bash apache -c "/var/www/html/dbnode.discover.sh $HOST_IP $new_master_host_name $DB_USERNAME $DB_PASSWORD"

####
## wait - do we really want to fail over?
## Let's try a connection to the failed node just to make sure.
####
if [ `/usr/pgsql-9.3/bin/psql -U pgpool_checker -h $failed_host_name -p 5432 -d postgres -c "SELECT 'CONNECTED'" | grep CONNECTED | wc -l` -eq 0 ]; then
####
## the connection failed, so trigger the failover
####
  if [ $failed_node_id = $old_primary_node_id ];then	# master failed
    su -s /bin/bash apache -c "ssh -T postgres@$new_master_host_name -p 49154 'touch /var/lib/pgsql/9.3/data/trigger'"	# let standby take over
  fi
fi
