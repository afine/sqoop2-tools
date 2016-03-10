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

# Working properties
host=''
username='root'
password='cloudera'
cm_login="admin:admin"
service_name="sqoop2_beta"

pwd=`pwd`

# Argument parsing
while getopts "p:t:u:w:h:c:i:" optname ; do
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
    "h")
      cm_login=$OPTARG
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

function cm_api() {
  echo "Calling CM API $1: $2"
  curl -sS -X $1 -u $cm_login -i "http://${host}:7180/api/v10/$2" -H "content-type:application/json" -d "$3" 2>&1
}

function cm_get() {
  cm_api "GET" "$1"
}

function cm_post() {
  cm_api "POST" "$1" "$2"
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


versions=( $(cm_get clusters/$url_cluster/parcels | grep -A1 "SQOOP2_BETA" | grep version | cut -c 18- | rev | cut -c 3- | rev) )

for version in "${versions[@]}"
do
  cm_post clusters/$url_cluster/parcels/products/SQOOP2_BETA/versions/$version/commands/deactivate {}

  cm_post clusters/$url_cluster/parcels/products/SQOOP2_BETA/versions/$version/commands/startRemovalOfDistribution {}

  cm_post clusters/$url_cluster/parcels/products/SQOOP2_BETA/versions/$version/commands/removeDownload {}
done
