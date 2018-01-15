#!/bin/bash
# -*- mode: sh -*-
# (C) Copyright IBM Corporation 2016
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

# Check various processes that guarantee that the Integration Node and the Integration Server 
# run as expected.

IIB_NODE_NAME=$1
IIB_INSTALL_DIRECTORY=/opt/ibm/$(ls /opt/ibm/ | grep [i]ib | awk 'NR==1{ print $1 }')

# Auxiliary subroutine used to return the state of the Integration Node.
state()
{
    mqsilist ${IIB_NODE_NAME} | awk 'NR==2{ print $NF }'
}

# Auxiliary subroutine used to verify the name of the Integration Node.
getNodeName()
{
    mqsilist | awk 'NR==1{ print $4 }'
}

# Auxiliary subroutine used to grep for a specific process, given as argument.
getProcess()
{
    PROCESS=$1
    ps -ef | grep $PROCESS | awk 'NR==1{ print $8 }'
}

# Auxiliary subroutine used to grep for a specific IIB process, given as argument, 
# and return the integration Node associated with that IIB process.
getIIBNodename()
{
    PROCESS=$1
    ps -ef | grep $PROCESS | awk 'NR==1{ print $9 }'
}

# Checks to see if the DataFlowEngine process is running
# Returns 1 if the DataFlowEngine process is running, with the right node name and false otherwise
checkDataFlowEngineProc()
{
    if [ "$(getProcess [D]ataFlowEngine)" == "DataFlowEngine" ] &&  [ $(getIIBNodename [D]ataFlowEngine) == "${IIB_NODE_NAME}" ]; then
        return 1
    fi
    return 0
}

# Checks to see if the bipservice process is running
# Returns 1 if the bipservice process is running, with the right node name and false otherwise
checkBipserviceProc()
{
    if [ "$(getProcess [b]ipservice)" == "bipservice" ] &&  [ $(getIIBNodename [b]ipservice) == "${IIB_NODE_NAME}" ]; then
        return 1
    fi
    return 0
}

# Checks to see if the bipbroker process is running
# Returns 1 if the bipbroker process is running, with the right node name and false otherwise
checkBipbrokerProc()
{
    if [ "$(getProcess [b]ipbroker)" == "bipbroker" ] &&  [ $(getIIBNodename [b]ipbroker) == "${IIB_NODE_NAME}" ]; then
        return 1
    fi
    return 0
}

# Checks to see if the bipMQTT process is running
# Returns 1 if the bipMQTT process is running, with the right node name and false otherwise
checkBipMQTTProc()
{
    if [ "$(getProcess [b]ipMQTT)" == "bipMQTT" ]; then
        return 1
    fi
    return 0
}

if [ "$#" -lt 1 ]; then
  echo "Usage: iib-health-check iib-node-name"
  exit 1
fi

# Configure the iib user profile
. ${IIB_INSTALL_DIRECTORY}/server/bin/mqsiprofile

# Figure out the AWS region from the instance metadata JSON
AWS_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["region"]')
AWS_INSTANCE_ID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
while true; do
  sleep 20
  if [ "$(state)" != "running." ] ||  [ "$(getNodeName)" != "'${IIB_NODE_NAME}'" ]; then
        echo "broker not running at $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkBipserviceProc; then
        echo "bipservice not running at $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkBipbrokerProc; then
        echo "bip broker not running at $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkBipMQTTProc; then
        echo "bip MQTT not running at $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkDataFlowEngineProc; then
        echo "DataFlowEngine not running at $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

done
