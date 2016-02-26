#!/bin/bash
export HOST_IP=$1
export DB_USERNAME=$4
export DB_PASSWORD=$5
export PGPOOL_USERNAME=$6
## if ssh keys don't exist for root or apache, generate them
echo "Start"
if [ ! -f /root/.ssh/id_rsa ]; then
   echo "Make root ssh"
  /var/www/html/keygen.expect /root/.ssh
fi
if [ ! -f /var/www/.ssh/id_rsa ]; then
  su -s /bin/bash apache -c "/var/www/html/keygen.expect /var/www/.ssh"
fi

## create tunnel from fldengr login from VM to root@docker

if [ "`ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' fldengr@$HOST_IP 'echo 2>&1' && echo SSH__OK || echo SSH_NOK`" == "SSH_NOK" ]; then
  /var/www/html/root.tunnel.keygen.expect $HOST_IP /root/.ssh $PGPOOL_USERNAME
##  ssh -T fldengr@$HOST_IP /home/fldengr/docker.tunnel.discover.sh $HOST_IP /home/fldengr root dbaas10
##  ssh -T fldengr@$HOST_IP 'cat /home/fldengr/.ssh/id_rsa.pub' > /tmp/root.sshkey.$$
##  cat /tmp/root.sshkey.$$ >> /var/www/.ssh/authorized_keys
##  rm -f /tmp/root.sshkey.$$
fi

POSTGRES_NODES=`cat /tmp/pg.conf | grep -oP '(?<=database/postgres/postgres).*?(?=}|$)' |cut -d" " -f2`
## create connection to all postgres nodes

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

