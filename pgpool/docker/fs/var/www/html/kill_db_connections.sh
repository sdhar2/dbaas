#!/bin/bash
DB=$1
for pid in $(/bin/ps -ef | /bin/grep ' pgpool: ' | /bin/grep -v grep | /bin/grep ${DB} | /bin/awk ""' {print $2}' ); do /bin/kill -9 $pid; done
