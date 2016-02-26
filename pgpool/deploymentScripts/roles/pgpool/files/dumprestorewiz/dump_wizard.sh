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
prompt="Please select a database:"
options=( `/usr/local/dumprestorewiz/get_db_list.sh` "ALL" )


PS3="$prompt "
select opt in "${options[@]}" "Quit" ; do 
    if (( REPLY == 1 + ${#options[@]} )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        echo  "You picked $REPLY which is database $opt"
        echo $date' LOG: User chose database '$opt' to dump' >> $LOGLOCATION
        break

    else
        echo "Invalid option. Try another one."
    fi
done
db_dump.sh $opt MANUAL
echo "List of all database backup files for database $opt:"
echo "----------------------------------------------------"
ls -l /usr/local/dbbackups/*$opt.MANUAL*
dump_restore_wizard.sh
