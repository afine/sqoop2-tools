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

# Deploy parcels to CM

# We require sshpass utility here
# On Mac you can install it with:
# brew install http://git.io/sshpass.rb

# Working properties
parcel_repo='target/parcel_repo'
target_dir='/opt/cloudera/parcel-repo'
host=''
username='root'
password='cloudera'
workdir='target/'
cm_login="admin:admin"
pwd=`pwd`

# Argument parsing
while getopts "p:t:u:w:h:c:" optname ; do
  case "$optname" in
    "p")
      parcel_repo=$OPTARG
      ;;
    "t")
      target=$OPTARG
      ;;
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
echo "Parcel repository: $parcel_repo"
echo "Target directory: $target_dir"
echo "Host: $host"
echo "Username: $username"
echo "Password: $password"
echo "CM Login: $cm_login"

# We should have parcel repository already present
if [[ ! -d $parcel_repo ]]; then
  echo "Parcel repository $parcel_repo doesn't exists. Have you run parcel.sh script?"
  exit 1
fi

# Execute $1 on remote server
function remote_exec() {
  sshpass -p $password ssh -v -o 'StrictHostKeyChecking no' ${username}@${host} $1
}

# Copy $1 to $2 on remote server (e.g. upload)
function remote_copy() {
  sshpass -p $password scp -v -o 'StrictHostKeyChecking no' $1 ${username}@${host}:$2
}

# Execute givem CM REST API call
function cm_api() {
  echo "Calling CM API $1: $2"
  curl -sS -X $1 -u $cm_login -i "http://${host}:7180/api/v8/$2"
}
function cm_get() {
  cm_api "GET" "$1"
}
function cm_post() {
  cm_api "POST" "$1" > /dev/null
}

# Wait until parcel will get to given state
function cm_wait_for_parcel () {
  while [ 1 ]
  do
    # Retrieve current stage
    output=$(cm_get $1)

    # Our current stage
    stage=`echo $output| grep stage | sed -re "s/^.* \"stage\" : \"([A-Z]+)\".*\$/\1/"`

    # Breaking condition
    echo $stage | grep $2 > /dev/null && break

    # To keep us informed
    echo "Waiting on $1 to be $2, current stage is $stage"
    sleep 5
  done
}

# Preparing copy directory
copy_prep=$workdir/local_parcel_deploy
echo "Working in local parcel copy directory: $copy_prep"
rm -rf $copy_prep
mkdir -p $copy_prep

# By default we will copy parcels for all platforms to the target server. However
# if we're able to get platform of the remote box, then we'll simply copy only the
# relevant one.
remote_parcel=$(remote_exec "ls $target_dir | head -n 1")
remote_platform=`echo $remote_parcel | sed -re "s/^.*-([a-z0-9]+).parcel/\1/"`
echo "Remote parcel $remote_parcel with remote platform $remote_platform"
if [[ -n $remote_platform ]]; then
  cp $parcel_repo/*-$remote_platform.parcel $copy_prep
else
  cp $parcel_repo/*.parcel $copy_prep/
fi

# Generating checkusm
for filepath in $copy_prep/*.parcel; do
  file=$(basename $filepath)
  echo "Generating checksum for $file on path $filepath"
  sha1sum $filepath | cut -f1 -d' ' > $filepath.sha
done

# Getting product and version name as that will be required for CM APIs
product=`ls $parcel_repo/*-el6.parcel | sed -re "s/^.*\/(.*)-el6.parcel/\1/" | cut -f1 -d-`
version=`ls $parcel_repo/*-el6.parcel | sed -re "s/^.*\/(.*)-el6.parcel/\1/" | cut -f2,3,4 -d-`
echo "Detected product '$product' on version '$version'"

# Execute
echo "Uploading parcels"
remote_copy "$copy_prep/*" $target_dir

# Detecting cluster
cluster=$(cm_get "clusters" | grep "name" | sed -re "s/.*\"name\" : \"(.*)\".*/\1/")
url_cluster=$(echo "$cluster" | sed -re "s/ /%20/g")
echo "Detected '$cluster', for URL will use '$url_cluster'"

# We have to wait on downloaded state here is the parcel can be in state "UNAVAILABLE" at the begging (missing sha1 file)
cm_wait_for_parcel clusters/$url_cluster/parcels/products/$product/versions/$version DOWNLOADED

# Distributing parcel
cm_post clusters/$url_cluster/parcels/products/$product/versions/$version/commands/startDistribution
cm_wait_for_parcel clusters/$url_cluster/parcels/products/$product/versions/$version DISTRIBUTED

# Activate parcel
cm_post clusters/$url_cluster/parcels/products/$product/versions/$version/commands/activate
cm_wait_for_parcel clusters/$url_cluster/parcels/products/$product/versions/$version ACTIVATED
