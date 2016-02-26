#!/bin/bash
if [ "`ssh -q -o 'BatchMode=yes' -o 'ConnectTimeout=3' $3@$2 -p 49155 'echo 2>&1' && echo SSH__OK || echo SSH_NOK`" == "SSH_NOK" ]; then
  ssh-keygen -R [$2]:49155
  /var/www/html/pgpool.keycopy.expect $2 $3 $4
  ssh -o 'ConnectTimeout 30' -o 'StrictHostKeyChecking no' -T $3@$2 -p 49155 "/var/www/html/pgpool.discover.sh $2 $1 $3 $4"
fi
