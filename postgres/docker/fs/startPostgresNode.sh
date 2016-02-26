#!/bin/bash
touch /var/run/postgres_starting
cp /etcd/config/*.json /opt/etcd/config/
export ETCD_HOST=`host etcdCluster | cut -d " " -f4`:4001
export HostIP=$HOST_IP
service sshd start
/bin/etcdSanityChecker.sh postgres
keyname=`echo $HOST_IP| cut -f2 -d: | cut -f2-4 -d.`
etcdctl -no-sync -peers ${ETCD_HOST} rm /database/postgres/postgres$keyname > /dev/null 2>&1
etcdctl -no-sync -peers ${ETCD_HOST} rm /health/database/postgres/postgres$keyname > /dev/null 2>&1
etcdctl -no-sync -peers ${ETCD_HOST} rm /productGroups/dbaas/postgres@$HOST_NAME > /dev/null 2>&1
etcdctl -no-sync -peers ${ETCD_HOST} rm /health/productGroups/dbaas/postgres@$HOST_NAME > /dev/null 2>&1
sleep 5
etcdctl -no-sync -peers ${ETCD_HOST} set /database/postgres/postgres$keyname $HOST_IP
sleep 5
etcdctl -no-sync -peers ${ETCD_HOST} set /productGroups/dbaas/postgres@$HOST_NAME $HOST_IP
sleep 5
/bin/startConfd.sh &
sleep 5
/bin/startPostgres.sh &
sleep 5
/usr/sbin/check_postgres_health.sh 30 30 &
sleep 5
/usr/sbin/check_confd_health.sh &
/bin/bash
