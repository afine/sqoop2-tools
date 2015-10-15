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
service_name="Sqoop-2-beta"
service_host=''
service_yarn=''
pwd=`pwd`

# TODO:
# 1) Enable to specify databases and do some workaround for thme (like create DB, ...)

# Argument parsing
while getopts "u:w:h:c:n:s:y:" optname ; do
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
    "n")
      service_name=$OPTARG
      ;;
    "s")
      service_host=$OPTARG
      ;;
    "y")
      service_yarn=$OPTARG
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

if [[ -z $service_host ]]; then
  service_host=$host
fi

# Work itself
echo "Host: $host"
echo "Username: $username"
echo "Password: $password"
echo "CM Login: $cm_login"
echo "Service name: $service_name"
echo "Service host: $service_host"

# Execute $1 on remote server
function remote_exec() {
  echo "Executing command: $1"
  sshpass -p $password ssh ${username}@${host} $1
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

# Drop previous instance of the service if it exists
if [[ $(cm_get clusters/$url_cluster/services/$service_name | grep "\"name\" : \"$service_name\"" | wc -l) -gt 0 ]]; then
  echo "Detected previous instance of service $service_name"
  echo "Stopping the existing service:"
  cm_post clusters/$url_cluster/services/$service_name/commands/stop
  cm_wait_for_service clusters/$url_cluster/services/$service_name STOPPED

  echo "Removing the service:"
  cm_delete clusters/$url_cluster/services/$service_name
fi

# If YARN dependency haven't been specified we will identify it on our own
if [[ -z $service_yarn ]]; then
  service_yarn=$(cm_get clusters/$url_cluster/services | grep '"type" : "YARN"' -B 2 | grep "name" | sed -re "s/^.* \"name\" : \"([-A-Z0-9]+)\".*\$/\1/")
  echo "Identified running YARN instance: $service_yarn"
else
  echo "Using specified YARN dependency: $service_yarn"
fi

# Create service
echo "Creating service $service_name"
cm_post clusters/$url_cluster/services "{ \"items\" : [{\"name\" : \"$service_name\", \"type\" : \"SQOOP2_BETA\"}] }"

echo "Creating role for Sqoop 2 server"
cm_post clusters/$url_cluster/services/$service_name/roles "{ \"items\" : [{\"type\" : \"SQOOP2_SERVER\", \"hostRef\" : {\"hostId\" : \"$service_host\"}} ] }"

echo "Configuring the new role"
cm_put clusters/$url_cluster/services/$service_name/config "{ \"items\" : [{ \"name\" : \"yarn_service\", \"value\" : \"$service_yarn\" }] }"

echo "Starting the new service"
cm_post clusters/$url_cluster/services/$service_name/commands/firstRun ""

echo "Waiting on the service to start up"
cm_wait_for_service clusters/$url_cluster/services/$service_name STARTED