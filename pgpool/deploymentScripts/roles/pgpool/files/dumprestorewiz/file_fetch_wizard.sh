#!/bin/bash
####################################################################################
#Copyright 2014 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################
export COLUMNS=1
echo "Retrieving file list..."
if [ ! -f /usr/local/dumprestorewiz/dest_user ]; then
  sudo echo "NONE" > /usr/local/dumprestorewiz/dest_user
  sudo chmod 777 /usr/local/dumprestorewiz/dest_user
fi
echo "Please enter user on remote host [`cat /usr/local/dumprestorewiz/dest_user`]:"
read DEST_USER
if [[ -z $DEST_USER ]]
then
   DEST_USER=`cat /usr/local/dumprestorewiz/dest_user`
fi
echo "Selected user on remote host: "$DEST_USER
echo $DEST_USER > /usr/local/dumprestorewiz/dest_user

if [ ! -f /usr/local/dumprestorewiz/dest_host ]; then
  sudo echo "NONE" > /usr/local/dumprestorewiz/dest_host
  sudo chmod 777 /usr/local/dumprestorewiz/dest_host
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
  sudo echo "NONE" > /usr/local/dumprestorewiz/dest_dir
  sudo chmod 777 /usr/local/dumprestorewiz/dest_dir
fi
echo "Please enter directory on remote host [`cat /usr/local/dumprestorewiz/dest_dir`]:"
read DEST_DIR
if [[ -z $DEST_DIR ]]
then
   DEST_DIR=`cat /usr/local/dumprestorewiz/dest_dir`
fi
echo "Selected directory on remote host: "$DEST_DIR
echo $DEST_DIR > /usr/local/dumprestorewiz/dest_dir

/usr/local/dumprestorewiz/get_remote_file_list.sh $DEST_USER $DEST_HOST $DEST_DIR > /tmp/remotefilelist 2>/dev/null
if [ "$DEST_DIR" != "NONE" ] && [ "$DEST_USER" != "NONE" ] && [ "$DEST_HOST" != "NONE" ]; then
  prompt="Please select a local file:"
  options=( $( cat /tmp/remotefilelist | grep "dmp" | cut -d"." -f1 | sort -u ) )

  PS3="$prompt "
  select opt in "${options[@]}" "Quit" ; do 
    if (( REPLY == 1 + ${#options[@]} )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        echo  "You picked $REPLY which is database ${opt}"
        options2=($( cat /tmp/remotefilelist | grep ${opt} | cut -d"." -f7,8,9 | sort -rn ) )
        prompt2="Please select the date when the backup was taken: "
        PS3="$prompt2 "
        select opt2 in "${options2[@]}" "Quit" ; do
          if (( REPLY == 1 + ${#options2[@]} )) ; then
            exit
          elif (( REPLY > 0 && REPLY <= ${#options2[@]} )) ; then
            file=`cat /tmp/remotefilelist | grep $opt | grep $opt2`
            filename=`cat /tmp/remotefilelist | grep $opt | grep $opt2 | cut -d"/" -f5`
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
  
  echo "Copying "$filename" from "$DEST_USER"@"$DEST_HOST":"$DEST_DIR 
  sudo scp $DEST_USER@$DEST_HOST:$DEST_DIR/$filename /usr/local/dbbackups/$filename 2>/dev/null
  date=`date --utc +"%Y-%m-%d %H:%M:%S"`
  echo "$date LOG: Copying database backup file $filename from $DEST_HOST in $DEST_DIR to local." >> /var/log/pgpool/pgpool.log
  sudo chmod 644 /usr/local/dbbackups/$filename

  #if 'ALL' file, copy other files
  if [ `echo $filename | grep ALL | wc -l` -eq 1 ]; then
    fileList=""
    for fileToCopy in `sudo cat /usr/local/dbbackups/$filename`; do
      copyfile=/$DEST_DIR/${fileToCopy/\/*\//}
      fileList="$fileList $copyfile"
    done
    sudo scp $DEST_USER@$DEST_HOST:"$fileList" /usr/local/dbbackups/ 2>/dev/null
    date=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$date LOG: Copying database backup file $fileList from $DEST_HOST in $DEST_DIR to local." >> /var/log/pgpool/pgpool.log
  fi
  dump_restore_wizard.sh
else
  echo "ERROR: You need to specify valid values for user, host, and directory"
fi
