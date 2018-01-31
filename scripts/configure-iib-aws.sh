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

# Run all the neccesary configuration for IBM Integration Bus in High Availability mode.
set -e

if [ "$#" -lt 5 ]; then
  echo "Usage: configure-iib-aws iib-node-name integration-server-name qmgr-name file-system aws-region"
  exit 1
fi

configure_os_user()
{
  # The group ID of the user to configure
  local -r GROUP_NAME=$1
  # Name of environment variable containing the user name
  local -r USER_VAR=$2
  # Name of environment variable containing the password
  local -r PASSWORD=$3
  # Home directory for the user
  local -r HOME=$4

  # Determine the login name of the user (assuming it exists already)
  # if user does not exist
  if [ $(grep -c "^${USER_VAR}:" /etc/passwd) -eq 0 ]; then
    # create
    useradd --gid ${GROUP_NAME} --home ${HOME} ${USER_VAR}
  fi
  # Set the user's password
  echo ${USER_VAR}:${PASSWORD} | chpasswd
}

# Subroutine used to check if the queue manager is running
queue_manager_state()
{
 dspmq -n -m ${MQ_QMGR_NAME} | awk -F '[()]' '{ print $4 }'
}

IIB_NODE_NAME=$1
IIB_INTEGRATION_SERVER_NAME=$2
MQ_QMGR_NAME=$3
AWS_REGION=$4
AWS_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
IIB_ADMIN_NAME="iib"
IIB_ADMIN_PASSWORD=${5:-""}
IIB_WEBUI_USERNAME=${6:-"iibwebuiuser"}
IIB_WEBUI_PASSWORD=${7:-""}
IIB_INSTALL_DIR=/opt/ibm/$(ls /opt/ibm/ | grep [i]ib | awk 'NR==1{ print $1 }')

mkdir -p /HA/iib

if ! getent group mqbrkrs; then
  # Group doesn't exist already
  groupadd mqbrkrs
fi

# Create the iib user ID
echo "Configuring admin user"
configure_os_user mqbrkrs ${IIB_ADMIN_NAME} ${IIB_ADMIN_PASSWORD} /HA/iib
usermod -aG sudo,root,mqm ${IIB_ADMIN_NAME}

chown -R iib:mqbrkrs /HA/iib
chmod -R ug+rwx /HA/iib

configure_os_user mqbrkrs ${IIB_WEBUI_USERNAME} ${IIB_WEBUI_PASSWORD} /home/iibwebuiuser
usermod -aG sudo,root ${IIB_WEBUI_USERNAME}

#Configuring the iib user profile
echo ". ${IIB_INSTALL_DIR}/server/bin/mqsiprofile" > ~iib/.bash_profile
#Adding two commands needed to test a simple IIB application to the user profile
echo 'PATH=$PATH:/opt/mqm/samp/bin' >> ~iib/.bash_profile
chown iib.mqbrkrs ~iib/.bash_profile

if [ "$(queue_manager_state)" != "RUNNING" ]; then
  #start the queue manager before creating broker
  su mqm -c "strmqm ${MQ_QMGR_NAME}"
fi

systemctl daemon-reload

# Enable the systemd services to run at boot time

#Create an EnvironmentFile containing ${IIB_NODE_NAME} and ${QUEUE_MANAGER}, used to create the broker
echo "IIB_NODE_NAME=${IIB_NODE_NAME}" > /etc/.brokerconf
echo "QUEUE_MANAGER=${MQ_QMGR_NAME}" >> /etc/.brokerconf
echo "IIB_INTEGRATION_SERVER_NAME=${IIB_INTEGRATION_SERVER_NAME}"  >> /etc/.brokerconf
systemctl enable iib-configure-broker
systemctl enable iib-health-aws@${IIB_NODE_NAME}
systemctl enable port-health-aws

# Start the systemd services
systemctl start iib-configure-broker

/usr/local/bin/configure-iib-security ${IIB_NODE_NAME} ${IIB_INTEGRATION_SERVER_NAME} ${IIB_WEBUI_USERNAME} ${IIB_WEBUI_PASSWORD} ${MQ_QMGR_NAME} 

# Deploy a simple application
cmd="su - iib bash -c 'mqsichangeproperties ${IIB_NODE_NAME} -b httplistener -o HTTPListener -n startListener -v false'"
eval $cmd

cmd="su - iib bash -c 'mqsireload ${IIB_NODE_NAME} -e ${IIB_INTEGRATION_SERVER_NAME}'"
eval $cmd

cmd="su - iib bash -c 'mqsideploy ${IIB_NODE_NAME} -e ${IIB_INTEGRATION_SERVER_NAME} -a /iib/application/Ping_HTTP_MQ.bar'"
eval $cmd

# Start the port health checking only after all configuration is ready
systemctl start port-health-aws
systemctl start iib-health-aws@${IIB_NODE_NAME}