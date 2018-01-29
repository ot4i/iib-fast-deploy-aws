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

IIB_NODE_NAME=$1
IIB_INTEGRATION_SERVER_NAME=$2
IIB_WEBUI_USERNAME=$3
IIB_WEBUI_PASSWORD=$4

#Prerequisites for SSL

#Create the keystore and a certificate
mkdir -p /iib/keystore

if [ ! -f "/iib/keystore/${IIB_NODE_NAME}.jks" ]; then
    runmqckm -keydb -create -db /iib/keystore/${IIB_NODE_NAME} -pw ${IIB_WEBUI_PASSWORD} -type jks
    runmqckm -cert -create -db /iib/keystore/${IIB_NODE_NAME}.jks -label IIBCert -dn "CN=iib_serv,O=IBM,OU=DEV,L=Hursley,C=GB"  -pw ${IIB_WEBUI_PASSWORD}

    #Extract the certificate
    runmqckm -cert -extract -db /iib/keystore/${IIB_NODE_NAME}.jks -pw ${IIB_WEBUI_PASSWORD} -label IIBCert -target /iib/keystore/IIBCert.arm -format ascii

    #Set up the right permissions
    chgrp mqbrkrs /iib/keystore/${IIB_NODE_NAME}.jks
    chmod 660 /iib/keystore/${IIB_NODE_NAME}.jks 
    chmod 660 /iib/keystore/IIBCert.arm
fi

#Add the secure authentification before starting the broker
cmd="su - iib bash -c 'mqsistop ${IIB_NODE_NAME}'"
eval $cmd

cmd="su - iib bash -c 'mqsichangeauthmode ${IIB_NODE_NAME} -s active -m file'"
eval $cmd

cmd="su - iib bash -c 'mqsichangefileauth ${IIB_NODE_NAME} -r iibAdmins  -p read+,write+,execute+'"
eval $cmd

cmd="su - iib bash -c 'mqsichangefileauth ${IIB_NODE_NAME} -r iibAdmins -e ${IIB_INTEGRATION_SERVER_NAME} -p read+,write+,execute+'"
eval $cmd

cmd="su - iib bash -c 'mqsistart ${IIB_NODE_NAME} > /dev/null 2>/dev/null'"
eval $cmd

sleep 15

cmd="su - iib bash -c 'mqsiwebuseradmin ${IIB_NODE_NAME} -c -u ${IIB_WEBUI_USERNAME} -r iibAdmins -a ${IIB_WEBUI_PASSWORD}'"
eval $cmd

#SSL configuration

cmd="su - iib bash -c 'mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o server -n enableSSL -v true'"
eval $cmd

cmd="su - iib bash -c 'mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o HTTPSConnector -n port -v 4417'"
eval $cmd

cmd="su - iib bash -c 'mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o HTTPSConnector -n keystoreFile -v /iib/keystore/${IIB_NODE_NAME}.jks'"
eval $cmd

cmd="su - iib bash -c 'mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o HTTPSConnector -n keystorePass -v webadminkeystore::password'"
eval $cmd

cmd="su - iib bash -c 'mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o HTTPSConnector -n truststoreFile -v /iib/keystore/${IIB_NODE_NAME}.jks'"
eval $cmd

cmd="su - iib bash -c 'mqsichangeproperties ${IIB_NODE_NAME} -b webadmin -o HTTPSConnector -n truststorePass -v webadminkeystore::password'"
eval $cmd

cmd="su - iib bash -c 'mqsisetdbparms ${IIB_NODE_NAME} -n webadminkeystore::password -u ignore -p ${IIB_WEBUI_PASSWORD}'"
eval $cmd

cmd="su - iib bash -c 'mqsistop ${IIB_NODE_NAME}'"
eval $cmd

cmd="su - iib bash -c 'mqsistart ${IIB_NODE_NAME} > /dev/null 2>/dev/null'"
eval $cmd

sleep 15

