#!/bin/bash
cp /etcd/config/*.json /opt/etcd/config/
export ETCD_HOST=`host etcdCluster | cut -d " " -f4`:4001
export HostIP=$HOST_IP
touch /tmp/pgpool_starting
rm -f /tmp/pg.conf
service sshd start
service httpd start
/bin/etcdSanityChecker.sh pgpool
keyname=`echo $HOST_IP| cut -f2 -d: | cut -f2-4 -d.`
etcdctl -no-sync -peers ${ETCD_HOST} rm /database/pgpool/pgpool$keyname > /dev/null 2>&1
etcdctl -no-sync -peers ${ETCD_HOST} rm /health/database/pgpool/pgpool$keyname > /dev/null 2>&1
etcdctl -no-sync -peers ${ETCD_HOST} rm /productGroups/dbaas/pgpool@$HOST_NAME > /dev/null 2>&1
etcdctl -no-sync -peers ${ETCD_HOST} rm /health/productGroups/dbaas/pgpool@$HOST_NAME > /dev/null 2>&1
sleep 5
etcdctl -no-sync -peers ${ETCD_HOST} set /database/pgpool/pgpool$keyname $HOST_IP
sleep 5
etcdctl -no-sync -peers ${ETCD_HOST} set /productGroups/dbaas/pgpool@$HOST_NAME $HOST_IP
sleep 5
/bin/startConfd.sh &
sleep 5
/bin/startPgpool.sh &
sleep 5
/usr/sbin/check_pgpool_health.sh 60 60 &
sleep 5
/usr/sbin/check_confd_health.sh &
/bin/bash

