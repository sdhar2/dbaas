#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
## Confd Health Checker
while [ 1==1 ]; do
  sleep 60
  result=`ps -eaf | grep onfd | grep -v "grep" | grep -v "check_confd" | wc -l`
  if [ $result -eq 0 ]; then
    /bin/startConfd.sh &
  fi
done
