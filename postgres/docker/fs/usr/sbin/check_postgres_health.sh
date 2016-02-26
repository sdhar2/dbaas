## Postgres Health Checker 
INITSLEEPTIME=$1
SLEEPTIME=$2
keyname=`echo $HOST_IP| cut -f2 -d: | cut -f2-4 -d.`
etcdctl -no-sync -peers ${ETCD_HOST} set /health/database/postgres/postgres${keyname} $HOST_IP -ttl `expr $INITSLEEPTIME + 3`
sleep $INITSLEEPTIME
while [ 1==1 ]; do
  result=`ps -eaf | grep postgres | grep -v "grep" | grep -v "KeepAlive" | grep -v "check_postgres_health" | wc -l`
  if [ $result -gt 0 ]; then  
    etcdctl -no-sync -peers ${ETCD_HOST} set /health/database/postgres/postgres${keyname} $HOST_IP -ttl `expr $SLEEPTIME + 3`
    etcdctl -no-sync -peers ${ETCD_HOST} set /health/productGroups/dbaas/postgres@${HOST_NAME} $HOST_IP -ttl `expr $SLEEPTIME + 3`
  fi
  sleep $SLEEPTIME
done
