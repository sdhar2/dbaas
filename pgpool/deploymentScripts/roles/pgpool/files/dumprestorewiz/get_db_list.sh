#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
DOCKER_VERSION=1.0.0.40

echo "psql -h localhost -p 9999 -U pgpool_checker -w -P \"footer=off\" -P \"tuples_only\" -d postgres -c \"SELECT datname FROM pg_database WHERE datistemplate = false and datname != 'postgres';\" | cut -f2 -d\" \"" > /tmp/getdblist.$$
enter.sh arrs-cloud-base-pgpool: < /tmp/getdblist.$$ | egrep -v 'arrs-postgres|VM| '
rm -f /tmp/getdblist.$$
