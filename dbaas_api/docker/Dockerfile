####################################################################################
#Copyright 2015 ARRIS Enterprises, Inc. All rights reserved.
#This program is confidential and proprietary to ARRIS Enterprises, Inc. (ARRIS),
#and may not be copied, reproduced, modified, disclosed to others, published or used,
#in whole or in part, without the express prior written permission of ARRIS.
####################################################################################

# Docker build specification for dbaas_api 

# Pull base image
FROM arrs/arrs-cloud-base-nodejs7-1:1.0.0.2
MAINTAINER ARRIS

# Install openssl
RUN yum install -y openssl

# Install nodejs modules
WORKDIR /opt/webservice/
RUN npm install ssh2 
RUN npm install async 

#Install exec-sync and pg modules which cannot be installed via npm due to lack of g++
RUN wget -q -P /opt/webservice/node_modules http://areopagus/binaries/npm-exec-sync-0.1.6.tar.gz && cd /opt/webservice/node_modules && tar zxf npm-exec-sync-0.1.6.tar.gz && rm -rf npm-exec-sync-0.1.6.tar.gz

RUN wget -q -P /opt/webservice/node_modules http://areopagus/binaries/npm-pg-4.4.3.tar.gz && cd /opt/webservice/node_modules && tar zxf npm-pg-4.4.3.tar.gz && rm -rf npm-pg-4.4.3.tar.gz

# Add local files
ADD fs /

# Move dbaas_api specific nodejs files to a temp location
WORKDIR /opt
RUN mv main main_tmp
RUN mv keys keys_tmp

# Link the webservice NPM modules and skeleton
RUN ln -s /opt/webservice/ dbaas_api 

# Add dbaas_api specific nodejs files
RUN cp main_tmp/* dbaas_api/routes
RUN mv -f dbaas_api/routes/www dbaas_api/bin/.
RUN chmod +x dbaas_api/bin/www
RUN rm -rf main_tmp

RUN mkdir -p dbaas_api/keys
RUN cp keys_tmp/*.* dbaas_api/keys
RUN rm -rf keys_tmp 

# Create the SSL certificate path
RUN mkdir dbaas_api/bin/sslcert
RUN chmod 666 dbaas_api/bin/sslcert

# Add start scripts run permission
RUN chmod +x /create_config.sh
RUN chmod +x /start_dbaas_api.sh

# Run start dbaas_api
CMD /create_config.sh && /start_dbaas_api.sh
