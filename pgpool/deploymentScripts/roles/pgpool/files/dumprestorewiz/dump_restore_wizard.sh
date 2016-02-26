#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
export COLUMNS=1
if [ -f /var/log/pgpool/pgpool.log ]; then
  sudo chmod 777 /var/log/pgpool/pgpool.log
fi
export LOGLOCATION='/var/log/pgpool/pgpool.log'
if [ $USER != "fldengr" ]; then
   echo "This script is intended to only be run under the fldengr user.  Exiting." 
   exit 1
fi
## if we can't access running docker via enter.sh, exit. 
echo "echo connected" > /tmp/entershcheck.$$
if [ `enter.sh arrs-cloud-base-pgpool: < /tmp/entershcheck.$$ | grep connected | wc -l` -eq 0 ]; then
  echo "$date LOG: Cound not enter dump restore wizard: pgpool docker container not running!" >> $LOGLOCATION
  echo "Cound not enter dump restore wizard: pgpool docker container not running!"
  exit 1
fi
rm -f /tmp/entershcheck.$$
date=`date --utc +"%Y-%m-%d %H:%M:%S"`
echo "$date LOG: Entering dump restore wizard." >> $LOGLOCATION
PS3='Please enter your choice: '
options=("Dump from cluster" "Restore to cluster" "Copy Dump Files Offsite" "Retrieve Dump Files Offsite" "Enable Daily Backup" "Disable Daily Backup" "Quit")
select opt in "${options[@]}"
do
  case $opt in
        "Dump from cluster")
          echo "You chose Dump from cluster"
          echo "$date LOG: User chose Dump from cluster" >> $LOGLOCATION
          /usr/local/dumprestorewiz/dump_wizard.sh
          exit 1
          ;;
        "Restore to cluster")
          echo "You chose Restore to cluster"
          echo "$date LOG: User chose Restore to cluster" >> $LOGLOCATION
          /usr/local/dumprestorewiz/restore_wizard.sh
          exit 1
          ;;
        "Copy Dump Files Offsite")
          echo "You chose Copy Dump Files Offsite"
          echo "$date LOG: User chose Copy dump files offsite" >> $LOGLOCATION
          /usr/local/dumprestorewiz/file_copy_wizard.sh
          exit 1
          ;;
        "Retrieve Dump Files Offsite")
          echo "You chose Retrieve Dump Files Offsite"
          echo "$date LOG: User chose Retrieve dump files offsite" >> $LOGLOCATION
          /usr/local/dumprestorewiz/file_fetch_wizard.sh
          exit 1
          ;;
        "Enable Daily Backup")
          echo "You chose Enable Daily Backup"
          echo "$date LOG: User chose Enable daily backup" >> $LOGLOCATION
          /usr/local/dumprestorewiz/daily_backup_wizard.sh
          exit 1
          ;;
        "Disable Daily Backup")
          echo "You chose Disable Daily Backup"
          echo "$date LOG: User chose Disable daily backup" >> $LOGLOCATION
          /usr/local/dumprestorewiz/remove_backup_wizard.sh
          exit 1
          ;;
        "Quit")
          echo "$date LOG: User chose to exit." >> $LOGLOCATION
          exit 0
          ;;
      *) echo invalid option
          exit 1
          ;;
  esac
done
