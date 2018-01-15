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

# If initial installation copy the old configuration file and replace with sample basic_registry config
# chmod the correct read-write settings to the file
# insert a new line at 108 and then replace _HOSTNAME_ with the current IP Address
set -e

IPADDR="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"

if [ ! -d "/var/mqm/web/installations/Installation1/angular.persistence" ]; then
  mv /var/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml /var/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml.old

  cp /usr/local/bin/starter-registry.xml /var/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml

  chmod ug+w /var/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml

  sed -i "s/_HOSTNAME_/${IPADDR}/g" /var/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml

else
  sed -i "s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/${IPADDR}/" /var/mqm/web/installations/Installation1/servers/mqweb/mqwebuser.xml
fi
