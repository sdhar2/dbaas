SERVICE=$1
CHECKED_KEY=$2
RUNSERVICE_LOGFILE=/var/log/run_service.log
timestamp()
{
  date --rfc-3339=seconds
}

#############################
# Test DNS for etcd address
#############################
etcd_ip=""
while [ -z "$etcd_ip" ]
do
##    echo "$(timestamp) - Looping to get etcd_ip" >> $RUNSERVICE_LOGFILE
    response=`host etcdCluster`
    status=$?
##    echo "$(timestamp) - response is: $response" >> $RUNSERVICE_LOGFILE
##    echo "$(timestamp) - status is: $status" >> $RUNSERVICE_LOGFILE

    if [ $status -ne 0 ]
    then
            etcd_ip=""
    else
            etcd_ip=`echo $response | cut -d " " -f4`
            echo "$(timestamp) - Found etcd ip: $etcd_ip" >> $RUNSERVICE_LOGFILE
    fi
    sleep 5
done
export ETCD_HOST=`host etcdCluster | cut -d " " -f4`:4001

###############################################
# Check for the ability to add/rm a dummy key.
###############################################
gotkeys=0
while [ $gotkeys -eq 0 ]
do
    echo "$(timestamp) - Performing check to set/rm dummy etcd keys" >> $RUNSERVICE_LOGFILE
    response=`etcdctl --no-sync -peers  ${ETCD_HOST} set /123DUMMY${SERVICE} $HostIP`
    response=`etcdctl --no-sync -peers  ${ETCD_HOST} rm /123DUMMY${SERVICE} $HostIP`
    status=$?
    if [ $status -ne 0 ]
    then
            gotkeys=0
            sleep 15
    else
            echo "$(timestamp) - Set and removed dummy etcd keys." >> $RUNSERVICE_LOGFILE
            gotkeys=1
    fi
done

#################################################################
# Check for a specific key to be present before starting service.
#################################################################
echo "$(timestamp) - Checking for specified key." >> $RUNSERVICE_LOGFILE
if [ "$CHECKED_KEY" != "" ]; then
  KEYEXISTS=0
  while [ $KEYEXISTS -eq 0 ]; do
    response=`etcdctl --no-sync -peers  ${ETCD_HOST} get $CHECKED_KEY`
    status=$?
    if [ $status -ne 0 ]
    then
            KEYEXISTS=0
            sleep 15
    else
            echo "$(timestamp) - Found key $CHECKED_KEY." >> $RUNSERVICE_LOGFILE
            KEYEXISTS=1
    fi
  done  
else
   echo "$(timestamp) - No key to check.  Proceeding." >> $RUNSERVICE_LOGFILE
fi

####################################
# key is present, so start services.
####################################
