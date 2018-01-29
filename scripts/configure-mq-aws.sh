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

if [ "$#" -lt 3 ]; then
  echo "Usage: configure-mq-aws qmgr-name efs-id aws-region"
  exit 1
fi

set -e

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
  if ! id ${!USER_VAR} 2>1 > /dev/null; then
    # create
    useradd --gid ${GROUP_NAME} --home ${HOME} ${!USER_VAR}
  fi
  # Change the user's password (if set)
  if [ ! "${!PASSWORD}" == "" ]; then
    echo ${!USER_VAR}:${!PASSWORD} | chpasswd
  fi
}

MQ_QMGR_NAME=$1
FILE_SYSTEM=$2
AWS_REGION=$3
AWS_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
MQ_CONSOLE_USERNAME=${4:-"mqconsoleadmin"}
MQ_CONSOLE_PASSWORD=${5}
MQ_ADMIN_NAME="mqadmin"
MQ_ADMIN_PASSWORD=${6:-""}
MQ_APP_NAME="mqapp"
MQ_APP_PASSWORD=${7:-""}

mkdir -p /HA
mkdir -p /HA/logs


# Configure fstab to mount the EFS file system as boot time
echo "${AWS_ZONE}.${FILE_SYSTEM}.efs.${AWS_REGION}.amazonaws.com:/ /HA nfs4 defaults 0 2" >> /etc/fstab

# Mount the file system
mount /HA

mkdir -p /HA/mqm
mkdir -p /HA/mqm/logs
mkdir -p /HA/mqm/qmgrs
chown -R mqm:mqm /HA/mqm/*
chmod -R ug+rwx /HA/mqm

# Create the queue manager if it doesn't already exist
# Copy the mqwebuser configuration for the mqweb console

/opt/mqm/bin/amqicdir -i -f
/opt/mqm/bin/amqicdir -s -f

# Create/update the MQ directory structure under the mounted directory
if [ ! -d "/HA/mqm/qmgrs/${MQ_QMGR_NAME}" ]; then
  su mqm -c "crtmqm -ld /HA/mqm/logs -md /HA/mqm/qmgrs ${MQ_QMGR_NAME}" || exit 2
else
  su mqm -c "addmqinf -v DataPath=/HA/mqm/qmgrs/${MQ_QMGR_NAME}  -v Prefix=/var/mqm  -v Directory=${MQ_QMGR_NAME}  -v Name=${MQ_QMGR_NAME}"
fi

# Set Username and Password for MQ Console User
sudo sed -i "s/<USERNAME>/${MQ_CONSOLE_USERNAME}/g" /usr/local/bin/starter-registry.xml
sudo sed -i "s/<PASSWORD>/${MQ_CONSOLE_PASSWORD}/g" /usr/local/bin/starter-registry.xml

# Set needed variables to point to various MQ directories
DATA_PATH=`dspmqver -b -f 4096`
INSTALLATION=`dspmqver -b -f 512`

echo "Configuring app user"
if ! getent group mqclient; then
  # Group doesn't exist already
  groupadd mqclient
fi

configure_os_user mqclient MQ_APP_NAME MQ_APP_PASSWORD /home/app

echo "Configuring admin user"
configure_os_user mqm MQ_ADMIN_NAME MQ_ADMIN_PASSWORD /home/admin

# Add a systemd drop-in to create a dependency on the mount point
mkdir -p /etc/systemd/system/mq@${MQ_QMGR_NAME}.service.d
cat << EOF > /etc/systemd/system/mq@${MQ_QMGR_NAME}.service.d/mount-ha.conf
[Unit]
RequiresMountsFor=/HA
EOF

systemctl daemon-reload

# Enable the systemd services to run at boot time
systemctl add-wants multi-user.target rpcbind.service
systemctl enable mq@${MQ_QMGR_NAME}
systemctl enable mq-console-setup
systemctl enable mq-console
systemctl enable mq-health-aws@${MQ_QMGR_NAME}

# Start the systemd services
systemctl start mq@${MQ_QMGR_NAME}
systemctl start mq-console-setup
systemctl start mq-console
systemctl start mq-health-aws@${MQ_QMGR_NAME}

runmqsc ${MQ_QMGR_NAME} < /etc/config.mqsc
