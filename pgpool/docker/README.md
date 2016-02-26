docker-postgresql
=================

A docker.io recipe for generating a pgpool appliance to serve as the base of other appliances

Getting Started
---------------

To run the container you can do the following:

       docker run -e HOST_IP=<DB node IP> -e DB_MASTER_IP=<master DB node IP> -e DB_SLAVE_IP=<slave DB node IP> -e PGPOOL_ACTIVE_IP=<primary PgPool node IP> -e PGPOOL_STANDBY_IP=<standby PgPool node IP> -e PGPOOL_OTHER_IP=<standby or master PgPool node IP> -e PG_VIRTUAL_IP=<virtual IP for client connections> -e DB_USERNAME=<postgres superuser name> -e DB_PASSWORD=<postgres superuser password> -e PGPOOL_USERNAME=<PgPool superuser name> -e PGPOOL_PASSWORD=<PgPool superuser password> -p 5432:5432 -p 9999:9999 -p 9694:9694 -p 9000:9000 -p 80:80 -p 49154:22 -i -d -v /usr/local/docker/pgsql/data:/var/lib/pgsql/9.3/data -t cmcentos:5000/arrs/arrs-cloud-base-pgpool

Alternatively this can be run using the run_docker.sh file.  etcd will populate all of the inputs.

Ports exposed to the container are 5432 (database broadcast port), 49154 (ssh tunnel), 9999 (pgpool external connection port), 9694 (PgPool connectivity port), 9000 (PgPool port), 80 (PgPoolAdmin Web Interface)

The following commands are used to generate the output.bin file which contains the passwords. 
# generate a 2048-bit RSA key and store it in key.txt
  openssl genrsa -out key.txt 2048


# encrypt the passwords using the RSA key in key.txt (root unix user, postgres unix user, pgpoolAdmin password, postgres db user)
  echo "dbaas10 dbaas10 ippv4000 f2c27871"  | openssl rsautl -inkey key.txt -encrypt >output.bin

This command is used within the docker file
# decrypt the message and output to stdout
  openssl rsautl -inkey key.txt -decrypt <output.bin

