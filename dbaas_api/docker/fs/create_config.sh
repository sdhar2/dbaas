#!/bin/sh
#
######################################################################################
# Copyright 2009-2014 ARRIS Enterprises, Inc. All rights reserved.
# This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
# and may not be copied, reproduced, modified, disclosed to others, published
# or used, in whole or in part, without the express prior written permission of ARRIS.
######################################################################################
#
DOCKER_REPO=dockerrepo
ACPAPI_REPO_DIR="/service-scripts/certificates/ACPAPI"
ACPAPI_LOCAL_DIR="deployment$ACPAPI_REPO_DIR"
LOGFILE="/opt/dbaas_api/logs/createConfig.log"

timestamp() {
  date --rfc-3339=seconds
}

echo "$(timestamp) - DOCKER_REPO=$DOCKER_REPO" >> $LOGFILE 

wget -r -np -nH -R "index.*" -P deployment http://$DOCKER_REPO$ACPAPI_REPO_DIR/

if [[ `find $ACPAPI_LOCAL_DIR/keys/ -type f  | wc -l` -gt 0 ]];
then
  echo "$(timestamp) - Found ACPAPI key and certificate files in repository, copying" >> $LOGFILE
  rm -rf /opt/dbaas_api/bin/sslcert/*
  mv $ACPAPI_LOCAL_DIR/keys/* /opt/dbaas_api/bin/sslcert
else
  echo "$(timestamp) - Initial launch, ACPAPI key and certificate files not found in repository" >> $LOGFILE
fi

rm -rf deployment
