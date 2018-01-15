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

# Run all the necessary configuration for the Integration Node. This script can run either if 
# the machine is started for the first time (and no Integration Node has been configured on the
# specific machine or on the EFS), or if the same machine was rebooted.

IIB_NODE_NAME=$1
QUEUE_MANAGER=$2
IIB_INTEGRATION_SERVER_NAME=$3
IIB_INSTALL_DIRECTORY=/opt/ibm/$(ls /opt/ibm/ | grep [i]ib | awk 'NR==1{ print $1 }')

. ${IIB_INSTALL_DIRECTORY}/server/bin/mqsiprofile

check_broker_exists()
{
    mqsilist | awk 'NR==1{ print $1 }'
}

check_broker_status()
{
    mqsilist ${IIB_NODE_NAME} | awk 'NR==1{ print $NF }'
}

check_active_broker(){
    mqsilist | awk 'NR==1{ print $7 }'
}

check_eg_exists(){
    mqsilist ${IIB_NODE_NAME} | awk 'NR==1{ print $1 }'
}

# If the broker has not been created previously, create the Integration Node, start it and create the Integration Server.
if [ ! -d "/HA/iib/mqsi/registry/${IIB_NODE_NAME}" ]; then
    echo "Creating the first broker"
    mqsicreatebroker ${IIB_NODE_NAME} -q ${QUEUE_MANAGER} -e /HA/iib
    mqsichangebroker ${IIB_NODE_NAME} -f all
    mqsistart ${IIB_NODE_NAME} -w 300
    
    # Wait until the Integration Server starts running
    while [ ! "$(check_active_broker)" == "active"  ]; do
        sleep 2
    done
    echo "Creating the execution group"
    mqsicreateexecutiongroup ${IIB_NODE_NAME} -e ${IIB_INTEGRATION_SERVER_NAME}
else
    # If an Integration Server has not been defined before, create one
    if [ "$(check_eg_exists)" == "BIP1282I:" ]; then 
        mqsicreateexecutiongroup ${IIB_NODE_NAME} -e ${IIB_INTEGRATION_SERVER_NAME}
    fi

    # If no integration nodes exist on the current instance, then add it 
    if [ "$(check_broker_exists)" == "BIP1281I:" ]; then 
        echo "Adding the broker intstance"
        mqsiaddbrokerinstance ${IIB_NODE_NAME} -e /HA/iib
    fi

    # Start the broker
    if [ "$(check_broker_status)" == "stopped." ]; then 
        echo "Restarting the broker"
        mqsistart ${IIB_NODE_NAME}
    fi
fi