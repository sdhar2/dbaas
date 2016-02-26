#!/bin/bash
export HOST_IP=$1
export OTHERDBNODE=$2
export PGPOOLNODE1=$3
export PGPOOLNODE2=$4
export DB_USERNAME=$4
export DB_PASSWORD=$5
export PGPOOL_USERNAME=$6
export PGPOOL_PASSWORD=$7
## if ssh keys don't exist for postgres, generate them

if [ ! -f /var/lib/pgsql/.ssh/id_rsa ]; then
  su - postgres -c "/var/lib/pgsql/keygen.expect /var/lib/pgsql/.ssh"
fi
ping -c1 $OTHERDBNODE > /dev/null 2>&1
if [ `echo $?` -eq 0 ]
then
  su - postgres -c "/var/lib/pgsql/dbnode.discover.sh $MYNODE $OTHERDBNODE $MYNODE $DB_USERNAME $DB_PASSWORD"
fi
ping -c1 $PGPOOLNODE1 > /dev/null 2>&1
if [ `echo $?` -eq 0 ]
then
  su - postgres -c "/var/lib/pgsql/pgpool.discover.sh $MYNODE $PGPOOLNODE1 $PGPOOL_USERNAME $PGPOOL_PASSWORD"
fi
ping -c1 $PGPOOLNODE2 > /dev/null 2>&1
if [ `echo $?` -eq 0 ]
then
  su - postgres -c "/var/lib/pgsql/pgpool.discover.sh $MYNODE $PGPOOLNODE2 $PGPOOL_USERNAME $PGPOOL_PASSWORD"
fi
