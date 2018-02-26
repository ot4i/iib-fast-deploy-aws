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

# Helper script used to verify that the ports required to acces IBM MQ and IBM Integration Bus are open.
# This scripts enforces an unhealthy treshold of 5 - it checks 5 times is the port passed as argument to 
# this script is listening. If all of these attempts fail, it then marks the instance as unhealthy.

# Checks the state of a specific port, given as argument.
PORT=$1
COUNTER=0
UNHEALTHY_TRESHOLD=5

getPortStatus()
{
    netstat -atn | grep $PORT | awk 'NR==1{ print $NF }'
}

# Figure out the AWS region from the instance metadata JSON
AWS_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["region"]')
AWS_INSTANCE_ID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)

while [ "$COUNTER" -lt "$UNHEALTHY_TRESHOLD" ]; do
  if [ "$(getPortStatus $PORT)" != "LISTEN" ]; then
    sleep 10
  else
    exit 0
  fi
  COUNTER=$(($COUNTER + 1))
done

if [ "$(getPortStatus $PORT)" != "LISTEN" ]; then
    echo "port $PORT not listening at $(date +%H%M%S)" >> /HA/log/healthchecks.log
    aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
fi
