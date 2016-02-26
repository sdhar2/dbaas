#/bin/sh -x
#
# XXX We assume master and recovery host uses the same port number
PORT=5432
master_db_cluster=$1
recovery_node_host_name=$2
recovery_db_cluster=$3
db_username=$4
db_password=$5
master_node_host_name=`cat $master_db_cluster/myip`
echo "master_node_host_name = " $master_node_host_name
echo "I am " `whoami`
echo "My host is" `hostname`
echo "master_db_cluster = " $master_db_cluster
echo "recovery_node_host name = " $recovery_node_host_name
echo "recovery_db_cluster = " $recovery_db_cluster
tmp=/tmp/mytemp$$
trap "rm -f $tmp" 0 1 2 3 15

## This script should only be invoked on a MASTER creating a new base backup
## for a new STANDBY.

## First check the SSH tunnel and see if it's healthy.

#!/bin/bash
export CAN_I_CONNECT=`ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' $db_username@$recovery_node_host_name -p 49154 'echo 2>&1' && echo SSH__OK || echo SSH_NOK`

### If not, try to recreate it.
if [ "$CAN_I_CONNECT" == "SSH_NOK" ]; then
  /var/lib/pgsql/dbnode.discover.sh `cat $master_db_cluster/myip` $recovery_node_host_name $db_username $db_password
fi

### If it's still not good, exit.
export CAN_I_CONNECT=`ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' $db_username@$recovery_node_host_name -p 49154 'echo 2>&1' && echo SSH__OK || echo SSH_NOK`
if [ "$CAN_I_CONNECT" == "SSH_NOK" ]; then
  echo "ERROR: SSH TUNNEL NOT ESTABLISHED PROPERLY FOR REPLICATION.  Exiting." 
fi

## We can connect to the new master through the SSH tunnel.
## We don't care what the old recovery.conf was on the STANDBY.
## Make the correct one on the STANDBY.

cat > $tmp <<EOF
standby_mode          = 'on'
primary_conninfo      = 'host=$master_node_host_name port=$PORT user=$db_username'
trigger_file = '/var/lib/pgsql/9.3/data/trigger'
EOF
scp -P 49154 $tmp $db_username@$recovery_node_host_name:$recovery_db_cluster/recovery.conf

## Make critical myip file on the new STANDBY.

echo "$recovery_node_host_name" > $tmp
scp -P 49154 $tmp $db_username@$recovery_node_host_name:$recovery_db_cluster/myip

### Start the backup process on the MASTER.

psql -c "SELECT pg_start_backup('Streaming Replication', true)" postgres

### Rsync the cluster from the MASTER to the SLAVE.
### THIS IS EVERYTHING BUT THE DB DATA AND TRANSACTION LOGS

rsync -e 'ssh -p 49154' -C -az --delete --exclude postmaster.pid \
--exclude postmaster.opts --exclude pg_log \
--exclude recovery.conf --exclude recovery.done --exclude trigger --exclude base/ --exclude pg_xlog/ --exclude myip $master_db_cluster/ $db_username@$recovery_node_host_name:$recovery_db_cluster/ &

## THIS IS THE PG_XLOG INFO

rsync -e 'ssh -p 49154' -C -az --delete $master_db_cluster/pg_xlog/ $db_username@$recovery_node_host_name:$recovery_db_cluster/pg_xlog/ &

## THIS IS THE DATA PORTION

rsync -e 'ssh -p 49154' -C -az --delete $master_db_cluster/base/ $db_username@$recovery_node_host_name:$recovery_db_cluster/base/ 

## THIS IS THE FINAL RESYNC OF EVERYTHING

rsync -e 'ssh -p 49154' -C -az --delete --exclude postmaster.pid \
--exclude postmaster.opts --exclude pg_log \
--exclude recovery.conf --exclude recovery.done --exclude trigger --exclude myip $master_db_cluster/ $db_username@$recovery_node_host_name:$recovery_db_cluster/

### Now stop the backup process on the MASTER.

psql -c "SELECT pg_stop_backup()" postgres

### File cleanup on remote node (if necessary)

ssh -T $db_username@$recovery_node_host_name -p 49154 rm -f $recovery_db_cluster/trigger
###ssh -T $db_username@$recovery_node_host_name -p 49154 rm -f $recovery_db_cluster/recovery.done

### Complete.  Once it runs clean, pgpool will initiate postgres coming up.
