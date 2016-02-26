#!/bin/bash
if [ "`ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' $3@$2 -p 49154 'echo 2>&1' && echo SSH__OK || echo SSH_NOK`" == "SSH_NOK" ]; then
  ssh-keygen -R [$2]:49154
  /var/www/html/dbnode.keycopy.expect $2 $3 $4
  ##su -s /bin/bash apache -c "ssh-keyscan -p 49154 $2 > /tmp/ssh-keyscan"
  ##su -s /bin/bash apache -c "sed -ri 's/'$2'/\['$2'\]:49154/g' /tmp/ssh-keyscan"
  ##su -s /bin/bash apache -c "cat /tmp/ssh-keyscan >> /var/www/.ssh/known_hosts"
  ##su -s /bin/bash apache -c "rm -f /tmp/ssh-keyscan"
  ssh -o 'ConnectTimeout 30' -o 'StrictHostKeyChecking no' -T $3@$2 -p 49154 "/var/lib/pgsql/pgpool.discover.sh $2 $1 root $4"
fi
