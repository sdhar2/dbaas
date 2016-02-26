#!/bin/bash
export PGPOOLADMIN_USERNAME=postgres
export PGPOOLADMIN_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f3`
sleep 1
pcp_watchdog_info 5 localhost 9898 $PGPOOLADMIN_USERNAME $PGPOOLADMIN_PASSWORD > /tmp/amiwatchdog.$$
AMIWATCHDOG=`awk '{ print $4 }' /tmp/amiwatchdog.$$`
rm -f /tmp/amiwatchdog.$$
if [ $AMIWATCHDOG == '3' ]; then
  echo 1
else
  echo 0
fi
