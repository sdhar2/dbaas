# docker-pgpool
#
# VERSION 0.1

#FROM arrs/arrs-cloud-base:1.1.0.3
FROM arrs/arrs-cloud-base-centos6-6:2.0.0.1
MAINTAINER ARRIS

# Install Locales
RUN echo 'LANG="en_US.UTF-8"' > /etc/sysconfig/i18n; echo 'SYSFONT="latarcyrheb-sun16"' >> /etc/sysconfig/i18n
RUN yum -y reinstall glibc-common
RUN source /etc/sysconfig/i18n

# install apache + php
RUN yum -y install curl  php

# create some pgpool directories and chage the owner to the apache user
RUN mkdir /var/run/pgpool; chown apache:apache /var/run/pgpool; mkdir /var/log/pgpool;chown apache:apache /var/log/pgpool

# install pg repo
RUN yum install -y pgdg-centos93

# install php + pg repo
RUN yum install -y postgresql93-libs php-pgsql php-mbstring pgpool-II-pg93

# httpd configuration changes 
RUN sed -ri 's/#NameVirtualHost *:80/NameVirtualHost *:80/g' /etc/httpd/conf/httpd.conf; sed -ri 's/# DefaultLanguage nl/DefaultLanguage en/g' /etc/httpd/conf/httpd.conf

# php configuration changes
RUN sed -ri 's/;date.timezone =/date.timezone = "America\/New_York"/g' /etc/php.ini; sed -ri 's/; extension_dir = ".\/"/extension_dir = "\/usr\/lib64\/php\/modules\/"/g' /etc/php.ini

RUN sed -ri 's/etc\/pgpool-II\//usr\/local\/etc\//g' /etc/init.d/pgpool; sed -ri 's/var\/log\/pgpool.log/var\/log\/pgpool\/pgpool.log/g' /etc/init.d/pgpool
RUN sed -ri 's/chown postgres/chown apache/g' /etc/init.d/pgpool; sed -ri 's/\$SU -l postgres -c \"\$PGPOOLDAEMON -f \$PGPOOLCONF \$OPTS \& u\"/\$PGPOOLDAEMON -f \$PGPOOLCONF \$OPTS \& /g' /etc/init.d/pgpool

# install pgpooladmin
RUN yum install -y pgpoolAdmin

# configuration files and scripts
ADD fs /
WORKDIR /

RUN touch /usr/local/etc/placeholder; chown -R apache:apache /usr/local/etc
RUN chmod -R 755 /etc/confd; chmod 755 /bin/*.sh; chmod -R 755 /usr/local; chmod -R 755 /var/www; chmod 755 /var; chmod 755 /bin; chmod 755 /etc; chmod 755 /usr; chmod -R 755 /usr/pgsql-9.3; ln -s /usr/pgsql-9.3/bin/psql /usr/bin/psql; ln -s /usr/pgsql-9.3/bin/pg_dump /usr/bin/pg_dump

RUN mkdir -p /usr/local/dbbackups
RUN chmod 755 /usr/local/bin/*; chmod 777 /usr/local/dbbackups
RUN chown -R apache:apache /var/www; chgrp apache /var/lib/php/session
RUN chmod 755 /var/www/html/*; chmod 777 /var/www/html/pgpoolAdmin/conf/pgmgt.conf.php

# install ssh
RUN echo "root:dbaas10" | chpasswd
RUN yum install -y openssh openssh-server openssh-clients expect
RUN sed -ri 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config; sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config; sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config; sed -ri 's/#ClientAliveInterval 0/ClientAliveInterval 30/g' /etc/ssh/sshd_config; sed -ri 's/#ClientAliveCountMax 3/ClientAliveCountMax 4/g' /etc/ssh/sshd_config; sed -ri 's/#Port 22/Port 49155/g' /etc/ssh/sshd_config; chmod 755 /startPgpoolNode.sh; ln -s /usr/local/bin/confd /usr/local/sbin/confd;  ln -s /usr/local/bin/etcdctl /usr/local/sbin/etcdctl; chmod 755 /usr/sbin/check_pgpool_health.sh; chmod 755 /usr/sbin/check_confd_health.sh

#prime sshd
RUN /etc/init.d/sshd start; /etc/init.d/sshd stop

EXPOSE 5433 9999 9694 9000 49155 22 80

CMD /startPgpoolNode.sh
