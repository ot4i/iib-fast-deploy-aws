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

# Installs IBM Integration Bus on a Ubuntu image.
# Note this step only installs the product. It does not accept the licence or create an IIB userid
# That is done in the configuration stage.

# Fail on error
set -e
export DEBIAN_FRONTEND=noninteractive

IIB_INSTALL_DIR=/opt/ibm/${IIB_VERSION}

if [ `id -un` != "root" ]; then
  exec su - root -- $0 "$@"
fi

#timedatectl set-timezone UTC

# Recommended: Update all packages to the latest level
apt-get update
apt-get upgrade -y
apt-get update

# These packages should already be present, but let's make sure
apt-get install -y \
    bash \
    curl \
    rpm \
    super \
    tar  \
    bc \
    ca-certificates \
    coreutils \
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
    util-linux

python3 --version

pip3 --version

sudo pip3 install awscli --upgrade

sudo aws --version

sudo aws configure set aws_access_key_id ${AWS_ACCESS_KEY}
sudo aws configure set aws_secret_access_key ${AWS_SECRET_KEY}

# Make the destination directory
mkdir -p /opt/ibm

# Download and extract the IIB installation files
mkdir -p /tmp/iib
cd /tmp/iib
aws s3 cp ${IIB_URL} /tmp/iib
tar -zxvf ./*.tar.gz --exclude ${IIB_VERSION}/tools -C /opt/ibm

# Recommended: Create the iib user ID with a fixed UID and group, so that the
# file permissions work between different images
groupadd --gid 2345 mqbrkrs
useradd --uid 2345 --gid mqbrkrs --home-dir /HA/iib iib
usermod -a -G mqm,mqbrkrs root

# Configure file limits for the iib user
echo "iib       hard  nofile     10240" >> /etc/security/limits.conf
echo "iib       soft  nofile     10240" >> /etc/security/limits.conf

# Clean up all the downloaded files
cd ..
rm -rf /tmp/iib
# Clean up unwanted files, to help ensure a smaller image file is created
apt-get clean -y

# Accept the license - this will also create group a for mqbrkrs and allocate files in /var/mqsi
${IIB_INSTALL_DIR}/iib make registry global accept license silently

# Move the scripts required to configure IIB on an instance
cp /tmp/configure-iib-aws /usr/local/bin
chmod +x /usr/local/bin/configure-iib-aws

cp /tmp/run-iib-cmd /usr/local/bin
chmod +x /usr/local/bin/run-iib-cmd

cp /tmp/configure-iib-security /usr/local/bin
chmod +x /usr/local/bin/configure-iib-security

#Get bar files required to run an IIB application
mkdir -p /iib/application
cp /tmp/Ping_HTTP_MQ.bar /iib/application




