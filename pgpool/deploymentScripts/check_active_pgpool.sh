#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################

if [ `ip a | grep eth0 | grep inet | wc -l` -gt 1 ]
then
  echo "Active Pgpool"
else
  echo "Standby Pgpool"
fi
