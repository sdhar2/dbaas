#!/bin/bash
DEBUG=""
if [ "$1" == "y" ]; then
 DEBUG="-d"
fi
pgpool -c -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf $DEBUG -n -D -m fast stop >> /var/log/pgpool/pgpool.log
sleep 15
pgpool -c -f /usr/local/etc/pgpool.conf -a /usr/local/etc/pool_hba.conf -F /usr/local/etc/pcp.conf $DEBUG -n -D & >> /var/log/pgpool/pgpool.log 
