#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
export COLUMNS=1
echo ""
crontab -l | grep daily_backup
echo ""
prompt="Please select a database:"
options=( `crontab -l | grep daily_backup | awk '{print $7}'` )

PS3="$prompt "
select opt in "${options[@]}" "Quit" ; do
    if (( REPLY == 1 + ${#options[@]} )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        echo  "You picked $opt which is database $REPLY"
        break

    else
        echo "Invalid option. Try another one."
    fi
done
if [ `crontab -l | grep daily_backup | grep $opt | wc -l` -eq 0 ]; then
   echo "No existing backup of "$opt" in crontab."
else
   echo "Deleting Existing backup of "$opt" in crontab"
   if [ -f /tmp/crontab ]; then
     sudo rm -f /tmp/crontab
   fi
   crontab -l | egrep -v "(daily_backup.*$opt)" > /tmp/crontab
   crontab /tmp/crontab
fi
echo ""
echo "Entry deleted."
echo ""
crontab -l | grep daily_backup
date=`date --utc +"%Y-%m-%d %H:%M:%S"`
echo "$date LOG: Deleted daily backup entry for $opt." >> /var/log/pgpool/pgpool.log
echo ""
/usr/sbin/dump_restore_wizard.sh
