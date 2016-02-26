#!/bin/bash
NUMNODES=`pcp_node_count 5 localhost 9898 $1 $2`
for i in $(seq 0 `expr $NUMNODES - 1`); do
   pcp_node_info 5 localhost 9898 $1 $2 $i > /tmp/primarydbnode.$$
   DBNODE=`awk '{ print $1 }' /tmp/primarydbnode.$$`
   rm -f /tmp/primarydbnode.$$
   if [ `su -s /bin/bash apache -c "ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' postgres@$DBNODE -p 49154 'echo 2>&1' && echo SSH__OK || echo SSH_NOK"` == SSH__OK ]; then
     if [ `su -s /bin/bash apache -c "ssh -T postgres@$DBNODE -p 49154 'ls -lrt /var/lib/pgsql/9.3/data | grep recovery.conf'" | wc -l` -eq 0 ]; then
       echo $DBNODE
       exit 0
     fi
   fi
done
