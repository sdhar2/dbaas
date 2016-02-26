#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
export DB=$1
export DUMPTYPE=$2
export pg_virtual_ip=`host dbaasCluster | cut -d " " -f4`
echo "/var/www/html/dump_db_vip.sh $DB $pg_virtual_ip postgres $DUMPTYPE" > /tmp/dump.$$
enter.sh arrs-cloud-base-pgpool: < /tmp/dump.$$ > /dev/null 2>/dev/null
date=`date --utc +"%Y-%m-%d %H:%M:%S"`
echo "$date LOG: Completed database dump of $DB." >> /var/log/pgpool/pgpool.log
rm -f /tmp/dump.$$
