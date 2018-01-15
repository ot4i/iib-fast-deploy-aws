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

# Check various processes that guarantee that the Queue Manager runs as expected.

MQ_QMGR_NAME=$1

# Auxiliary subroutine used to return the state of the Queue Manager.
state()
{
    dspmq -n -m ${MQ_QMGR_NAME} | awk -F '[()]' '{ print $4 }'
}

# Auxiliary subroutine used to grep for a specific process, given as argument.
getProcess()
{
    PROCESS=$1
    ps -ef | grep $PROCESS | awk 'NR==1{ print $8 }'
}

# Auxiliary subroutine used to grep for a specific MQ process, given as argument, 
# and return the Queue Manager associated with that MQ process.
getQueueManagername()
{
    PROCESS=$1
    ps -ef | grep $PROCESS | awk 'NR==1{ print $10 }'
}

# Checking MQ specific processes

# Checks to see if the amqzxma0 process is running
# Returns 1 if the amqzxma0 process is running, with the right node name and false otherwise
checkAMQZXMA0Proc()
{
    if [[ $(getProcess [a]mqzxma0) == "/opt/mqm/bin/amqzxma0" ]] && [[ $(getQueueManagername [a]mqzxma0) == "${MQ_QMGR_NAME}" ]]; then
        return 1
    fi
    return 0
}

# Checks to see if the amqzfuma process is running
# Returns 1 if the amqzfuma process is running, with the right node name and false otherwise $(getProcess amqzxma0) == "/opt/mqm/bin/amqzxma0" 
checkAMQZFUMAProc()
{
    if [[ $(getProcess [a]mqzfuma) == "/opt/mqm/bin/amqzfuma" ]] && [[ $(getQueueManagername [a]mqzfuma) == "${MQ_QMGR_NAME}" ]]; then
        return 1
    fi
    return 0
}

# Checks to see if the amqzmuc0 process is running
# Returns 1 if the amqzmuc0 process is running, with the right node name and false otherwise
checkAMQZMUC0Proc()
{
    if [[ $(getProcess [a]mqzmuc0) == "/opt/mqm/bin/amqzmuc0" ]] && [[ $(getQueueManagername [a]mqzmuc0) == "${MQ_QMGR_NAME}" ]]; then
        return 1
    fi
    return 0
}

# Checks to see if the amqzmur0 process is running
# Returns 1 if the [a]mqzmur0 process is running, with the right node name and false otherwise
checkAMQZMUR0Proc()
{
    if [[ $(getProcess [a]mqzmur0) == "/opt/mqm/bin/amqzmur0" ]] && [[ $(getQueueManagername [a]mqzmur0) == "${MQ_QMGR_NAME}" ]]; then
        return 1
    fi
    return 0
}

# Checks to see if the amqzmuf0 process is running
# Returns 1 if the amqzmuf0 process is running, with the right node name and false otherwise
checkAMQZMUF0Proc()
{
    if [[ $(getProcess [a]mqzmuf0) == "/opt/mqm/bin/amqzmuf0" ]] && [[ $(getQueueManagername [a]mqzmuf0) == "${MQ_QMGR_NAME}" ]]; then
        return 1
    fi
    return 0
}

# Checks to see if the amqrrmfa process is running
# Returns 1 if the amqrrmfa process is running, with the right node name and false otherwise
checkAMQRRMFAProc()
{
    if [[ $(getProcess [a]mqrrmfa) == "/opt/mqm/bin/amqrrmfa" ]] && [[ $(getQueueManagername [a]mqrrmfa) == "${MQ_QMGR_NAME}" ]]; then
        return 1
    fi
    return 0
}

# Checks to see if the amqzmgr0 process is running
# Returns 1 if the amqzmgr0 process is running, with the right node name and false otherwise
checkAMQZMGR0Proc()
{
    if [[ $(getProcess [a]mqzmgr0) == "/opt/mqm/bin/amqzmgr0" ]] && [[ $(getQueueManagername [a]mqzmgr0) == "${MQ_QMGR_NAME}" ]]; then
        return 1
    fi
    return 0
}

# Checks to see if the amqfqpub process is running
# Returns 1 if the amqfqpub process is running, with the right node name and false otherwise
checkAMQFQPUBProc()
{
    if [[ $(getProcess [a]mqfqpub) == "/opt/mqm/bin/amqfqpub" ]]; then
        return 1
    fi
    return 0
}

# Checks to see if the amqpcsea process is running
# Returns 1 if the amqpcsea process is running, with the right node name and false otherwise
checkAMQPCSEAProc()
{
    if [[ $(getProcess [a]mqpcsea) == "/opt/mqm/bin/amqpcsea" ]]; then
        return 1
    fi
    return 0
}

# Checks to see if the amqfcxba process is running
# Returns 1 if the amqfcxba process is running, with the right node name and false otherwise
checkAMQFCXBAProc()
{
    if [[ $(getProcess [a]mqfcxba) == "/opt/mqm/bin/amqfcxba" ]] && [[ $(getQueueManagername [a]mqfcxba) == "${MQ_QMGR_NAME}" ]]; then
        return 1
    fi
    return 0
}

if [ "$#" -lt 1 ]; then
  echo "Usage: mq-health-check qmgr-name"
  exit 1
fi
# Figure out the AWS region from the instance metadata JSON
AWS_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["region"]')
AWS_INSTANCE_ID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
while true; do
  sleep 20

  if [ "$(state)" != "RUNNING" ]; then
      echo "QM NOT RUNNING $(date +%H%M%S)" >> /HA/log/healthchecks.log
      aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkAMQZXMA0Proc; then
        echo "AMQZXMA0 found not running $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkAMQZFUMAProc; then
        echo "AMQZFUMA found not running $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkAMQZMUC0Proc ; then
        echo "AMQZMUC0 found not running $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkAMQZMUR0Proc; then
        echo "AMQZMUR0 found not running $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkAMQZMUF0Proc; then
        echo "AMQZMUF0 found not running $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkAMQRRMFAProc; then
        echo "AMQRRMFA found not running $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkAMQZMGR0Proc; then
        echo "AMQZMGR0 found not running $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkAMQFQPUBProc; then
        echo "AMQFQPUB found not running $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkAMQPCSEAProc; then
        echo "AMQPCSEA found not running $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

  if checkAMQFCXBAProc; then
        echo "AMQFCXBA found not running $(date +%H%M%S)" >> /HA/log/healthchecks.log
        aws autoscaling set-instance-health --instance-id ${AWS_INSTANCE_ID}  --health-status Unhealthy --region ${AWS_REGION}
  fi

done
