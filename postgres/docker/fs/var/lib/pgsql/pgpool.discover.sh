#!/bin/bash
if [ "`ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' $3@$2 -p 49155 'echo 2>&1' && echo SSH__OK || echo SSH_NOK`" == "SSH_NOK" ]; then
  ssh-keygen -R [$2]:49155
  /var/lib/pgsql/pgpool.keycopy.expect $2 $3 $4
##  ssh-keyscan -p 49155 $2 > /tmp/ssh-keyscan
##  sed -ri 's/'$1'/\['$2'\]:49155/g' /tmp/ssh-keyscan
##  cat /tmp/ssh-keyscan >> /var/lib/pgsql/.ssh/known_hosts
##  rm -f /tmp/ssh-keyscan
  ssh -o 'ConnectTimeout 30' -o 'StrictHostKeyChecking no' -T root@$2 -p 49155 "su -s /bin/bash apache -c '/var/www/html/dbnode.discover.sh $2 $1 postgres $4'"
fi
