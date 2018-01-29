#!/bin/bash
# -*- mode: sh -*-
# (C) Copyright IBM Corporation 2016,2017
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

# Installs IBM MQ on a Ubuntu image.
# Fail on error
set -e
export DEBIAN_FRONTEND=noninteractive

if [ `id -un` != "root" ]; then
  exec su - root -- $0 "$@"
fi

timedatectl set-timezone UTC

# Recommended: Update all packages to the latest level
apt-get update
apt-get upgrade -y
apt-get update
# These packages should already be present, but let's make sure
apt-get install -y --no-install-recommends \
    bash \
    bc \
    ca-certificates \
    coreutils \
    curl \
    debianutils \
    file \
    findutils \
    gawk \
    grep \
    libc-bin \
    lsb-release \
    mount \
    passwd \
    procps \
    python3-pip \
    python3-setuptools \
    sed \
    tar \
    alien \
    util-linux

python3 --version

pip3 --version

sudo pip3 install awscli --upgrade

sudo aws --version

sudo aws configure set aws_access_key_id ${AWS_ACCESS_KEY}
sudo aws configure set aws_secret_access_key ${AWS_SECRET_KEY}

# Download and extract the MQ installation files
mkdir -p /images/mq
mkdir -p /tmp/mq
cd /tmp/mq
aws s3 cp ${MQ_URL} /tmp/mq
tar -zxvf ./*.tar.gz -C /images/mq

# Recommended: Create the mqm user ID with a fixed UID and group, so that the
# file permissions work between different images
groupadd --gid 1234 mqm
useradd --uid 1234 --gid mqm --home-dir /HA/mqm mqm
usermod -G mqm root
usermod -aG sudo,root mqm

# Configure file limits for the mqm user
echo "mqm       hard  nofile     10240" >> /etc/security/limits.conf
echo "mqm       soft  nofile     10240" >> /etc/security/limits.conf

# Configure kernel parameters to values suitable for running MQ
CONFIG=/etc/sysctl.conf
cp ${CONFIG} /etc/sysctl.conf.bak
sed -i '/^fs.file-max\s*=/{h;s/=.*/=524288/};${x;/^$/{s//fs.file-max=524288/;H};x}' ${CONFIG}
sed -i '/^kernel.shmmni\s*=/{h;s/=.*/=4096/};${x;/^$/{s//kernel.shmmni=4096/;H};x}' ${CONFIG}
sed -i '/^kernel.shmmax\s*=/{h;s/=.*/=268435456/};${x;/^$/{s//kernel.shmmax=268435456/;H};x}' ${CONFIG}
sed -i '/^kernel.shmall\s*=/{h;s/=.*/=2097152/};${x;/^$/{s//kernel.shmall=2097152/;H};x}' ${CONFIG}
sed -i '/^kernel.sem\s*=/{h;s/=.*/=32 4096 32 128/};${x;/^$/{s//kernel.sem=32 4096 32 128/;H};x}' ${CONFIG}

cd /images/mq/${MQ_DIRECTORY}
# Accept the MQ license
./mqlicense.sh -text_only -accept
echo "deb [trusted=yes] file:/images/mq/${MQ_DIRECTORY} ./" > /etc/apt/sources.list.d/IBM_MQ.list
# Install MQ using the DEB packages
apt-get update
apt-get install ${MQ_PACKAGES}

# Recommended: Set the default MQ installation (makes the MQ commands available on the PATH)
/opt/mqm/bin/setmqinst -p /opt/mqm -i

# Clean up all the downloaded files
rm -rf /tmp/mq

# Create a templated systemd service for running MQ
cp /tmp/mq@.service /etc/systemd/system/
cp /tmp/mq-console.service /etc/systemd/system/
cp /tmp/mq-console-setup.service /etc/systemd/system/
cp /tmp/configure-mq-aws /usr/local/bin
cp /tmp/configure-mq-console /usr/local/bin
cp /tmp/starter-registry.xml /usr/local/bin
chmod +x /usr/local/bin/configure-mq-aws
chmod +x /usr/local/bin/configure-mq-console
cp /tmp/config.mqsc /etc