# docker-postgresql
#
# VERSION 0.1

##FROM arrs/arrs-cloud-base:1.1.0.3
FROM arrs/arrs-cloud-base-centos6-6:2.0.0.1
MAINTAINER ARRIS


# Install Locales
RUN echo 'LANG="en_US.UTF-8"' > /etc/sysconfig/i18n
RUN echo 'SYSFONT="latarcyrheb-sun16"' >> /etc/sysconfig/i18n
RUN yum -y reinstall glibc-common
RUN source /etc/sysconfig/i18n

# install pg repo
RUN yum install -y pgdg-centos93

# install server
##RUN yum install -y postgresql93-server postgresql93-contrib

RUN yum install -y postgresql93-server postgresql93-contrib openssh openssh-server openssh-clients expect rsync

# configuration files and scripts
ADD fs /
WORKDIR /

RUN chmod -R 755 /etc/confd; chmod 755 /bin/*.sh; chown postgres /var/lib/pgsql; chgrp postgres /var/lib/pgsql; chmod 777 /var/lib/pgsql/*; chmod -R 755 /usr/local/bin/*; chmod 755 /var/lib/pgsql; chmod 755 /var/lib; chmod 755 /var; chmod 755 /bin; chmod 755 /etc; chmod 755 /usr; chmod -R 755 /usr/pgsql-9.3; chmod 777 /var/lib/pgsql/.bash_profile
RUN mkdir /var/log/postgres

# install ssh
RUN echo "root:dbaas10" | chpasswd
RUN echo "postgres:dbaas10" | chpasswd
##RUN yum install -y openssh openssh-server openssh-clients expect rsync
RUN sed -ri 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config; sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config; sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config; sed -ri 's/#ClientAliveInterval 0/ClientAliveInterval 30/g' /etc/ssh/sshd_config; sed -ri 's/#ClientAliveCountMax 3/ClientAliveCountMax 4/g' /etc/ssh/sshd_config; sed -ri 's/#Port 22/Port 49154/g' /etc/ssh/sshd_config; chmod 755 /startPostgresNode.sh; ln -s /usr/local/bin/confd /usr/local/sbin/confd; ln -s /usr/local/bin/etcdctl /usr/local/sbin/etcdctl; chmod 755 /usr/sbin/check_postgres_health.sh; chmod 755 /usr/sbin/check_confd_health.sh

#prime sshd
RUN /etc/init.d/sshd start; /etc/init.d/sshd stop

EXPOSE 5432 22 49154

##CMD  supervisord -c /etc/supervisord.conf
CMD /startPostgresNode.sh
