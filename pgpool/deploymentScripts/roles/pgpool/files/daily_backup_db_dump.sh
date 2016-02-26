#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
sudo /usr/sbin/db_dump.sh $1 DAILYBACKUP
sudo find /usr/local/dbbackups/$1.*DAILYBACKUP* -ctime +7 -delete
