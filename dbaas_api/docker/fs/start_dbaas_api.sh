####################################################################################
#Copyright 2015 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################

# NodeJS start up script for dbaas_api 

#!/bin/bash

mkdir -p /opt/etcd/config/
cp /etcd/config/*.json /opt/etcd/config/

/opt/node-v0.10.35-linux-x64/bin/node /opt/dbaas_api/bin/www $LISTEN_PORT
