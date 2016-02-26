#!/bin/bash

export PGPOOLADMIN_USERNAME=postgres
export PGPOOL_USERNAME=root
export DB_USERNAME=postgres

openssl rsautl -inkey /key.txt -decrypt </output.bin
export DB_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f1`
export PGPOOL_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f2`
export PGPOOLADMIN_PASSWORD=` openssl rsautl -inkey /key.txt -decrypt < /output.bin | cut -d " " -f3`

rm -f /tmp/postgres.conf

echo "`date` [postgres] starting up confd" > /tmp/confd.log
# Loop until confd has updated the postgres config
until confd -onetime -node $ETCD_HOST -config-file /etc/confd/conf.d/postgres.toml; do
  echo "`date` [postgres] waiting for confd to refresh pg_hba.conf" >> /tmp/confd.log
  sleep 5
done

# Run confd in the background to watch the db and postgres nodes
confd -interval 10 -node $ETCD_HOST -config-file /etc/confd/conf.d/postgres.toml  >> /var/log/confd.log &
echo "`date` [postgres] confd is listening for changes on etcd..." >> /tmp/confd.log

/bin/bash
