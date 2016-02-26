#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
HOSTIP=`hostname -I | awk '{ print $1 }'`
while [ 1 -eq 1 ]; do
  if [ -f /var/log/postgresDocker/rebootnode ]; then
    rm -f /var/log/postgresDocker/rebootnode
    docker-compose -f /arris/compose/postgres-compose.yml kill -s SIGKILL
    sleep 3
    keyname=`echo $HOSTIP| cut -f2 -d: | cut -f2-4 -d.`
    etcdctl -no-sync -peers etcdctl --no-sync -peers `host etcdcluster | cut -d " " -f4`:4001 rm /database/postgres/postgres${keyname}
    sleep 30
    docker-compose -f /arris/compose/postgres-compose.yml up -d --no-recreate
  fi
  sleep 60
done
