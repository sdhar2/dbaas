#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################

if [ `su - fldengr -c "crontab -l | grep clean_logs | wc -l"` -eq 0 ]; then
  su - fldengr -c "crontab -l > /tmp/crontab"
  su - fldengr -c "cat /usr/sbin/clean_logs_crontab >> /tmp/crontab"
  su - fldengr -c "crontab -r "
  su - fldengr -c "crontab /tmp/crontab"
  su - fldengr -c "rm -f /tmp/crontab"
fi