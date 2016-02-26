#!/bin/bash
###################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
export FILE=$1
export pg_virtual_ip=`host dbaasCluster | cut -d " " -f4`
echo "/var/www/html/restore_db_vip.sh $FILE $pg_virtual_ip postgres" > /tmp/dbrestore.$$
enter.sh arrs-cloud-base-pgpool: < /tmp/dbrestore.$$ | egrep -v 'arrs-cloud-base-pgpool|VM' 2>&1
date=`date --utc +"%Y-%m-%d %H:%M:%S"`
rm -f /tmp/dbrestore.$$
