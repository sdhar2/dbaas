#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
export COLUMNS=1
prompt="Please select a database:"
options=( `/usr/local/dumprestorewiz/get_db_list.sh` "ALL" )


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
   echo "No existing backup of "$opt" in crontab, making a new one"
else
   echo "Existing backup of "$opt" in crontab, deleting the old one first"
   if [ -f /tmp/crontab ]; then
     sudo rm -f /tmp/crontab
   fi
   crontab -l | egrep -v "(daily_backup.*$opt)" > /tmp/crontab
   crontab /tmp/crontab
fi
echo "Enter hour for backup of "$opt" database [0-23] :"
read HOUR
if [[ ! $HOUR || $HOUR = *[^0-9]* ]]; then
    echo "Error: '$HOUR' is not a number. Exiting..."
    exit 1
fi
echo "Enter minute for backup of "$opt" database [0-59] :"
read MINUTES
if [[ ! $MINUTES || $MINUTES = *[^0-9]* ]]; then
    echo "Error: '$MINUTES' is not a number. Exiting..."
    exit 1
fi
echo "Generating cron file:"
if [ -f /tmp/crontab ]; then
  sudo rm -f /tmp/crontab
fi
crontab -l > /tmp/crontab
echo "$MINUTES $HOUR * * * /usr/sbin/daily_backup_db_dump.sh $opt" >> /tmp/crontab
crontab /tmp/crontab
sudo rm -f /tmp/crontab
date=`date --utc +"%Y-%m-%d %H:%M:%S"`
echo "$date LOG: Added daily backup entry for $opt." >> /var/log/pgpool/pgpool.log
crontab -l 
/usr/sbin/dump_restore_wizard.sh
