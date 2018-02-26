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

# Fail on error
set -e

# Install NFS client, and other utils for this script
apt-get install -y \
  curl \
  python-setuptools \
  nfs-common \
  unzip

# Install the AWS command line
cd /tmp
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip /tmp/awscli-bundle.zip
/tmp/awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
rm -rf /tmp/awscli*

# Install the AWS-specific MQ health checking script
cp /tmp/check-mq-health-aws /usr/local/bin/
chmod +x /usr/local/bin/check-mq-health-aws

# Install the AWS-specific IIB health checking script
cp /tmp/check-iib-health-aws /usr/local/bin/
chmod +x /usr/local/bin/check-iib-health-aws

# Install the AWS-specific port health checking scripts for both MQ and IIB
cp /tmp/check-port-health-aws /usr/local/bin/
chmod +x /usr/local/bin/check-port-health-aws

cp /tmp/check-port-health-helper /usr/local/bin/
chmod +x /usr/local/bin/check-port-health-helper

# Install cloudformation bootstrap tooling
easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz

# Create a templated systemd service for checking the health of MQ
cp /tmp/mq-health-aws@.service /etc/systemd/system/
cp /tmp/iib-health-aws@.service /etc/systemd/system/
cp /tmp/port-health-aws.service /etc/systemd/system/
cp /tmp/iib-start-broker@.service /etc/systemd/system/