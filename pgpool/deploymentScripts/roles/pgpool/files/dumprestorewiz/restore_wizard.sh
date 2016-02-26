#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
export COLUMNS=1
export LOGLOCATION='/var/log/pgpool/pgpool.log'
date=`date --utc +"%Y-%m-%d %H:%M:%S"`
##Am I the primary pgpool?  If I'm not, don't try to restore.
dbvip=`host dbaasCluster | cut -d " " -f4`
AM_I_PRIMARY_PGPOOL=`ip a | grep $dbvip | wc -l`
if [ "$AM_I_PRIMARY_PGPOOL" == '1' ]; then 
##Get intersection of existing DBs and file DBs
  ls -1 /usr/local/dbbackups/ | cut -d"." -f1 | sort -u > /tmp/dbfilelist.$$
  /usr/local/dumprestorewiz/get_db_list.sh | sort -u  > /tmp/livedblist.$$
  ls -1 /usr/local/dbbackups/ | cut -d"." -f1 | sort -u | grep ALL >> /tmp/ALLlist.$$
  prompt="Please select a database:"
  options=( $( sort -m /tmp/dbfilelist.$$ /tmp/livedblist.$$ /tmp/ALLlist.$$| uniq -d ) )
  rm -f /tmp/dbfilelist.$$
  rm -f /tmp/livedblist.$$
  rm -f /tmp/ALLlist.$$
  PS3="$prompt "
  select opt in "${options[@]}" "Quit" ; do 
    if (( REPLY == 1 + ${#options[@]} )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        echo  "You picked $REPLY which is database $opt"
        echo "$date LOG: User chose database $opt to restore" >> $LOGLOCATION

        options2=($( ls -1 /usr/local/dbbackups/${opt}*dmp | cut -d"." -f7,8,9 | sort -rn ) )
        prompt2="Please select a date:"
        PS3="$prompt2 "
        select opt2 in "${options2[@]}" "Quit" ; do 
          if (( REPLY == 1 + ${#options2[@]} )) ; then
            exit
          elif (( REPLY > 0 && REPLY <= ${#options2[@]} )) ; then
            file=`ls -1 /usr/local/dbbackups/${opt}*${opt2}.dmp`
            filename=`ls -1 /usr/local/dbbackups/${opt}*${opt2}.dmp| cut -d"/" -f5`
            echo  "You picked date $opt2 which is file ${filename}"
            break
          else
            echo "Invalid option. Try another one."
          fi
        done    
        break
    else
        echo "Invalid option. Try another one."
    fi
  done    
  db_restore.sh $file
else
  echo "You are not running this on the active pgpool node.  This needs to be run on the active pgpool node.  Exiting."
fi
dump_restore_wizard.sh
