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
# This script will be run as part of the LaunchConfiguration and will configure the IBM Integration Bus 
# integration node. This runs a different configuration, considering whether this is the first instance 
# created in the environment, or it is an instance created after a failover coordinated by the Auto 
# Scaling Group. In the latter case, the integration node already picks up the previous configuration 
# from EFS and therefore only requires a few addtional steps to be configured.

echo configure-iib-aws started at $(date +%H:%M:%S)

if [ "$#" -lt 5 ]; then
  echo "Usage: configure-iib-aws iib-node-name integration-server-name qmgr-name file-system aws-region"
  exit 1
fi

# Subroutine used to configure a userid.
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
    useradd --system --gid ${GROUP_NAME} --home ${HOME} ${USER_VAR}
  fi
  # Set the user's password
  echo ${USER_VAR}:${PASSWORD} | chpasswd
}

# Subroutine used to check if the queue manager is running
queue_manager_state()
{
 dspmq -n -m ${MQ_QMGR_NAME} | awk -F '[()]' '{ print $4 }'
}

# Subroutine used to check if the integration node is running
check_active_broker(){
    su - iib -c "mqsilist | awk 'NR==1{ print \$7 }'"
}

# Subroutine used to check if the integration node exists
check_broker_exists()
{
    su - iib -c "mqsilist | awk 'NR==1{ print \$1 }'"
}

# Subroutine used to check if the integration server exists
check_eg_exists(){
    su - iib -c "mqsilist ${IIB_NODE_NAME} | awk 'NR==2{ print \$1 }'"
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
systemctl enable iib-start-broker@${IIB_NODE_NAME}
systemctl enable iib-health-aws@${IIB_NODE_NAME}
systemctl enable port-health-aws

# Check to see if the broker has been previously created. If it has not, that means that this instance is the first one 
# started in this system. Then, create the Integration Node, start it and create the Integration Server.
if [ ! -d "/HA/iib/mqsi/registry/${IIB_NODE_NAME}" ]; then

  echo "Creating the first broker"
  su - iib -c "mqsicreatebroker ${IIB_NODE_NAME} -q ${MQ_QMGR_NAME} -e /HA/iib"

  su - iib -c "mqsichangebroker ${IIB_NODE_NAME} -f all"

  #Start the broker. This is done as a systemd service, to ensure that the broker is started every time *this* instance is booted up.
  systemctl start iib-start-broker@${IIB_NODE_NAME}

  # Wait until the Integration Node starts running
  while [ ! "$(check_active_broker)" == "active"  ]; do
    sleep 2
  done

  echo "Creating the execution group"
  su - iib -c "mqsicreateexecutiongroup ${IIB_NODE_NAME} -e ${IIB_INTEGRATION_SERVER_NAME}"

  # Disable broker HTTP listener
  su - iib -c "mqsichangeproperties ${IIB_NODE_NAME} -b httplistener -o HTTPListener -n startListener -v false"

  # Configure SSL security on the IIB web UI
  /usr/local/bin/configure-iib-security ${IIB_NODE_NAME} ${IIB_INTEGRATION_SERVER_NAME} ${IIB_WEBUI_USERNAME} ${IIB_WEBUI_PASSWORD} ${MQ_QMGR_NAME}

  # Deploy a sample application
  su - iib -c "mqsideploy ${IIB_NODE_NAME} -e ${IIB_INTEGRATION_SERVER_NAME} -a /iib/application/Ping_HTTP_MQ.bar"

# This means that the current instance is not the first one in the system and it has been started after a failover.
else 

    # If no integration nodes exist on the current instance, then add it 
    if [ "$(check_broker_exists)" == "BIP1281I:" ]; then 
        echo "Adding the broker intstance"
        su - iib -c "mqsiaddbrokerinstance ${IIB_NODE_NAME} -e /HA/iib"
    fi

    #Start the broker. This is done as a systemd service, to ensure that the broker is started every time *this* instance is booted up.
    systemctl start iib-start-broker@${IIB_NODE_NAME}

    # Wait until the Integration Server starts running
    while [ ! "$(check_active_broker)" == "active"  ]; do
        sleep 2
    done

    # If an Integration Server has not been defined before, create one
    if [ ! "$(check_eg_exists)" == "BIP1286I:" ]; then 
        su - iib -c "mqsicreateexecutiongroup ${IIB_NODE_NAME} -e ${IIB_INTEGRATION_SERVER_NAME}"
    fi

fi

# Start the port health checking only after all configuration is ready
systemctl start port-health-aws
systemctl start iib-health-aws@${IIB_NODE_NAME}

echo configure-iib-aws finished at $(date +%H:%M:%S)