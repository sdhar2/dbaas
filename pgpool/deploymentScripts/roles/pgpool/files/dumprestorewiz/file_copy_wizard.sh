#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
export COLUMNS=1
DELETEME=2
prompt="Please select the database backup file:"
options=( $( ls -1 /usr/local/dbbackups/ | cut -d"." -f1 | sort -u ) )

PS3="$prompt "
select opt in "${options[@]}" "Quit" ; do 
    if (( REPLY == 1 + ${#options[@]} )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        echo  "You picked $REPLY which is database ${opt}"
        options2=($( ls -1 /usr/local/dbbackups/${opt}*dmp | cut -d"." -f7,8,9 | sort -rn ) )
        prompt2="Please select the date when the backup was taken: "
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
if [ ! -f /usr/local/dumprestorewiz/dest_user ]; then
  echo "NONE" > /usr/local/dumprestorewiz/dest_user
fi
echo "Please enter user on remote host [`cat /usr/local/dumprestorewiz/dest_user`]:"
read DEST_USER
if [[ -z $DEST_USER ]]
then
   DEST_USER=`cat /usr/local/dumprestorewiz/dest_user`
fi
echo "Selected remote host user: "$DEST_USER 
echo $DEST_USER > /usr/local/dumprestorewiz/dest_user

if [ ! -f /usr/local/dumprestorewiz/dest_host ]; then
  echo "NONE" > /usr/local/dumprestorewiz/dest_host
fi
echo "Please enter remote host IP [`cat /usr/local/dumprestorewiz/dest_host`]:"
read DEST_HOST
if [[ -z $DEST_HOST ]]
then
   DEST_HOST=`cat /usr/local/dumprestorewiz/dest_host`
fi
echo "Selected remote host IP: "$DEST_HOST
echo $DEST_HOST > /usr/local/dumprestorewiz/dest_host

if [ ! -f /usr/local/dumprestorewiz/dest_dir ]; then
  echo "NONE" > /usr/local/dumprestorewiz/dest_dir
fi
echo "Please enter directory on remote host [`cat /usr/local/dumprestorewiz/dest_dir`]:"
read DEST_DIR
if [[ -z $DEST_DIR ]]
then
   DEST_DIR=`cat /usr/local/dumprestorewiz/dest_dir`
fi
echo "Selected directory on remote host: "$DEST_DIR
echo $DEST_DIR > /usr/local/dumprestorewiz/dest_dir

if [ "$DEST_DIR" != "NONE" ] && [ "$DEST_USER" != "NONE" ] && [ "$DEST_HOST" != "NONE" ]; then 
  if [ `echo $filename | grep ALL | wc -l` -eq 1 ]; then
    file=/usr/local/dbbackups/*`echo $filename | cut -c 4-`
  fi
  echo "Copying "$filename" to "$DEST_USER"@"$DEST_HOST":"$DEST_DIR 
  scp $file $DEST_USER@$DEST_HOST:$DEST_DIR 2>/dev/null
  DELETEME=$?
  date=`date --utc +"%Y-%m-%d %H:%M:%S"`
  echo "$date LOG: Copying database backup file $copyfile to $DEST_HOST in $DEST_DIR." >> /var/log/pgpool/pgpool.log
  if [ $DELETEME == 0 ]; then  
    echo "Delete the file after copy? [y|N]"
    read DELFILE
    if [ "$DELFILE" != "y" ] && [ "$DELFILE" != "Y" ]; then
      echo "Retaining file "$file
      date=`date +"%Y-%m-%d %H:%M:%S"`
      echo "$date LOG: Retaining file $copyfile after remote file copy." >> /var/log/pgpool/pgpool.log
    else  
      echo "Deleting file "$copyfile
      date=`date +"%Y-%m-%d %H:%M:%S"`
      echo "$date LOG: Deleting file $copyfile after remote file copy." >> /var/log/pgpool/pgpool.log
      sudo rm -f $file
    fi
  else
    echo "Error copying file "$file
    date=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$date ERROR: Error copying $copyfile." >> /var/log/pgpool/pgpool.log
  fi
  dump_restore_wizard.sh
else
  echo "ERROR: You need to specify valid values for user, host, and directory"
fi

