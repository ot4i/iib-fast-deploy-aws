#!/bin/bash
# -*- mode: sh -*-
# (C) Copyright IBM Corporation 2017
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Configure the login to the IBM Integration Bus Web User Interface, using SSL.

echo configure-iib-security started at $(date +%H:%M:%S)

IIB_NODE_NAME=$1
IIB_INTEGRATION_SERVER_NAME=$2
IIB_WEBUI_USERNAME=$3
IIB_WEBUI_PASSWORD=$4
MQ_QMGR_NAME=$5

#Prerequisites for SSL

echo "STOP LISTENER('SYSTEM.DEFAULT.LISTENER.TCP')" | runmqsc ${MQ_QMGR_NAME}

#Create the keystore and a certificate
mkdir -p /HA/iib/keystore

if [ ! -f "/HA/iib/keystore/${IIB_NODE_NAME}.jks" ]; then
    runmqckm -keydb -create -db /HA/iib/keystore/${IIB_NODE_NAME} -pw ${IIB_WEBUI_PASSWORD} -type jks
    runmqckm -cert -create -db /HA/iib/keystore/${IIB_NODE_NAME}.jks -label IIBCert -dn "CN=iib_serv,O=IBM,OU=DEV,L=Hursley,C=GB"  -pw ${IIB_WEBUI_PASSWORD}

    #Extract the certificate
    runmqckm -cert -extract -db /HA/iib/keystore/${IIB_NODE_NAME}.jks -pw ${IIB_WEBUI_PASSWORD} -label IIBCert -target /HA/iib/keystore/IIBCert.arm -format ascii

    #Set up the right permissions
    chgrp mqbrkrs /HA/iib/keystore/${IIB_NODE_NAME}.jks
    chmod 660 /HA/iib/keystore/${IIB_NODE_NAME}.jks 
    chmod 660 /HA/iib/keystore/IIBCert.arm
fi

#Add the secure authentification before starting the broker
su - iib -c "mqsistop ${IIB_NODE_NAME}"

su - iib -c "mqsichangeauthmode ${IIB_NODE_NAME} -s active -m file"

su - iib -c "mqsichangefileauth ${IIB_NODE_NAME} -r iibAdmins  -p read+,write+,execute+"

su - iib -c "mqsichangefileauth ${IIB_NODE_NAME} -r iibAdmins -e ${IIB_INTEGRATION_SERVER_NAME} -p read+,write+,execute+"


su - iib -c "mqsistart ${IIB_NODE_NAME} > /dev/null 2>/dev/null"

sleep 15

su - iib -c "mqsiwebuseradmin ${IIB_NODE_NAME} -c -u ${IIB_WEBUI_USERNAME} -r iibAdmins -a ${IIB_WEBUI_PASSWORD}"

#SSL configuration

su - iib -c "mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o server -n enableSSL -v true"

su - iib -c "mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o HTTPSConnector -n port -v 4417"

su - iib -c "mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o HTTPSConnector -n keystoreFile -v /HA/iib/keystore/${IIB_NODE_NAME}.jks"

su - iib -c "mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o HTTPSConnector -n keystorePass -v webadminkeystore::password"

su - iib -c "mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o HTTPSConnector -n truststoreFile -v /HA/iib/keystore/${IIB_NODE_NAME}.jks"

su - iib -c "mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o HTTPSConnector -n truststorePass -v webadminkeystore::password"

su - iib -c "mqsisetdbparms ${IIB_NODE_NAME} -n webadminkeystore::password -u ignore -p ${IIB_WEBUI_PASSWORD}"

su - iib -c "mqsistop ${IIB_NODE_NAME}"

su - iib -c "mqsistart ${IIB_NODE_NAME} > /dev/null 2>/dev/null"

sleep 15

echo "START LISTENER('SYSTEM.DEFAULT.LISTENER.TCP')" | runmqsc ${MQ_QMGR_NAME}

echo configure-iib-security finished at $(date +%H:%M:%S)