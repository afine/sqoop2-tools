#!/bin/bash
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

# Deploy Service to Hadoop cluster

# Working properties
host=''
username='root'
password='cloudera'
cm_login="admin:admin"
service=''
workdir='target'
pwd=`pwd`

# TODO:
# 1) Enable to specify databases and do some workaround for thme (like create DB, ...)

# Argument parsing
while getopts "u:w:h:c:y:" optname ; do
  case "$optname" in
    "u")
      username=$OPTARG
      ;;
    "w")
      password=$OPTARG
      ;;
    "h")
      host=$OPTARG
      ;;
    "c")
      cm_login=$OPTARG
      ;;
    "y")
      service=$OPTARG
      ;;
    "?")
      echo "Unknown option $OPTARG"
      exit 1
      ;;
    *)
      # Should not occur
      echo "Unknown error while processing options"
      exit 1
      ;;
  esac
done

# Parameter checking
if [[ -z $host ]]; then
  echo "Missing argument -h with CM host"
  exit 1
fi

# Work itself
echo "Host: $host"
echo "Username: $username"
echo "Password: $password"
echo "CM Login: $cm_login"
echo "Workdir: $workdir"

# Execute $1 on remote server
function remote_exec() {
  echo "Executing command: $1"
  sshpass -p $password ssh -o 'StrictHostKeyChecking no' ${username}@${host} $1
}

# Copy $1 to $2 on remote server (e.g. upload)
function remote_copy() {
  echo "Executing command: scp $1 ${username}@${host}:$2"
  sshpass -p $password scp $1 ${username}@${host}:$2
}

# Execute givem CM REST API call
function cm_api() {
  echo "Calling CM API $1: $2"
  curl -sS -X $1 -u $cm_login -i "http://${host}:7180/api/v10/$2" -H "content-type:application/json" -d "$3" 2>&1
}
function cm_get() {
  cm_api "GET" "$1"
}
function cm_put() {
  cm_api "PUT" "$1" "$2"
}
function cm_post() {
  cm_api "POST" "$1" "$2"
}
function cm_delete() {
  cm_api "DELETE" "$1"
}

# Wait until parcel will get to given state
function cm_wait_for_service () {
  api=$1
  state=$2
  while [ 1 ]
  do
    output=$(cm_get $api)
    message=`echo $output | grep serviceState | sed -re "s/^.* \"serviceState\" : \"([A-Z]+)\".*\$/\1/"`

    # Breaking condition
    echo $message | grep "$2" > /dev/null && break

    # To keep us informed
    echo "Waiting on state $2, found $message"
    sleep 5
  done
}

# Detecting cluster
cluster=$(cm_get "clusters" | grep "name" | sed -re "s/.*\"name\" : \"(.*)\".*/\1/")
url_cluster=$(echo "$cluster" | sed -re "s/ /%20/g")
echo "Detected '$cluster', for URL will use '$url_cluster'"

# If YARN dependency haven't been specified we will identify it on our own
if [[ -z $service ]]; then
  service=$(cm_get clusters/$url_cluster/services | grep '"type" : "YARN"' -B 2 | grep "name" | sed -re "s/^.* \"name\" : \"([-A-Z0-9]+)\".*\$/\1/")
  echo "Identified running service: $service"
else
  echo "Using specified service: $service"
fi

# Get the client configs
wget http://${host}:7180/api/v10/clusters/$url_cluster/services/$service/clientConfig -O $workdir/clientConfig-$service.zip
