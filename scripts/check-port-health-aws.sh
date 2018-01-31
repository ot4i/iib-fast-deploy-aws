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

# Verify that the ports required to acces IBM MQ and IBM Integration Bus are open.

# Checks the state of a specific port, given as argument.
getPortStatus()
{
    PORT=$1
    netstat -atn | grep $PORT | awk 'NR==1{ print $NF }'
}

# Figure out the AWS region from the instance metadata JSON
AWS_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["region"]')
AWS_INSTANCE_ID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
while true; do
  sleep 40
  if [ "$(getPortStatus [1]414)" != "LISTEN" ]; then
       echo "port 1414 not listening at $(date +%H%M%S)" >> /HA/log/healthchecks.log
       aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if [ "$(getPortStatus [9]443)" != "LISTEN" ]; then
       echo "port 9443 not listening at $(date +%H%M%S)" >> /HA/log/healthchecks.log
       aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if [ "$(getPortStatus [4]417)" != "LISTEN" ]; then
       echo "port 4417 not listening at $(date +%H%M%S)" >> /HA/log/healthchecks.log
       aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if [ "$(getPortStatus [7]800)" != "LISTEN" ]; then
       echo "port 7800 not listening at $(date +%H%M%S)" >> /HA/log/healthchecks.log
       aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

done
