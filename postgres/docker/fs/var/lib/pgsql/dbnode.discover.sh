#!/bin/bash
if [ "`ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' $3@$2 -p 49154 'echo 2>&1' && echo SSH__OK || echo SSH_NOK`" == "SSH_NOK" ]; then
  ssh-keygen -R [$2]:49154
  /var/lib/pgsql/dbnode.keycopy.expect $1 $2 $3 $4
##  ssh-keyscan -p 49154 $1 > /tmp/ssh-keyscan
##  sed -ri 's/'$1'/\['$1'\]:49154/g' /tmp/ssh-keyscan
##  cat /tmp/ssh-keyscan >> /var/lib/pgsql/.ssh/known_hosts
##  rm -f /tmp/ssh-keyscan
  ssh -o 'ConnectTimeout 30' -o 'StrictHostKeyChecking no' -T $3@$2 -p 49154 "/var/lib/pgsql/dbnode.discover.sh $2 $1 $3 $4"
fi
