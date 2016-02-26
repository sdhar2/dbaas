#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
## Pgpool Health Checker
INITSLEEPTIME=$1
SLEEPTIME=$2
keyname=`echo $HOST_IP| cut -f2 -d: | cut -f2-4 -d.`
etcdctl -no-sync -peers ${ETCD_HOST} set /health/database/pgpool/pgpool${keyname} $HOST_IP -ttl `expr $INITSLEEPTIME + 3`
sleep $INITSLEEPTIME
while [ 1==1 ]; do
  result=`ps -eaf | grep " pgpool: " | grep -v "grep" | grep -v "KeepAlive" | grep -v "enter.sh" | wc -l`
  if [ $result -gt 0 ]; then
    etcdctl -no-sync -peers ${ETCD_HOST} set /health/database/pgpool/pgpool${keyname} $HOST_IP -ttl `expr $SLEEPTIME + 3`
    etcdctl -no-sync -peers ${ETCD_HOST} set /health/productGroups/dbaas/pgpool@${HOST_NAME} $HOST_IP -ttl `expr $SLEEPTIME + 3`
  fi
  sleep $SLEEPTIME
done
