#!/bin/bash
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
pwd=`pwd`

# Argument parsing
while getopts "p:t:u:w:h:" optname ; do
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

# We should have parcel repository already present
if [[ ! -d $parcel_repo ]]; then
  echo "Parcel repository $parcel_repo doesn't exists. Have you run parcel.sh script?"
  exit 1
fi

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
  curl -sS -X $1 -u "admin:admin" -i "http://${host}:7180/api/v8/$2"
}
function cm_get() {
  cm_api "GET" "$1"
}
function cm_post() {
  cm_api "POST" "$1"
}

# Wait until parcel will get to given state
function cm_wait_for_parcel () {
  while [ 1 ]
  do
    cm_get $1 | grep '"stage" : "'$2'"' && break
    echo "Waiting on $1 to be $2"
    sleep 5
  done
}

# Preparing copy directory
copy_prep=$workdir/local_parcel_deploy
echo "Working in local parcel copy directory: $copy_prep"
rm -rf $copy_prep
mkdir -p $copy_prep
cp $parcel_repo/*.parcel $copy_prep/

# Generating checkusm
for filepath in $copy_prep/*.parcel; do
  file=$(basename $filepath)
  echo "Generating checksum for $file on path $filepath"
#  sha1sum $filepath | cut -f1 -d' ' > $filepath.sha
done

# Getting product and version name as that will be required for CM APIs
product=`ls $copy_prep/*-el6.parcel | sed -re "s/^.*\/(.*)-el6.parcel/\1/" | cut -f1 -d-`
version=`ls $copy_prep/*-el6.parcel | sed -re "s/^.*\/(.*)-el6.parcel/\1/" | cut -f2,3,4 -d-`
echo "Detected product '$product' on version '$version'"

# Execute
echo "Uploading parcels"
#remote_copy "$copy_prep/*" $target_dir

# Detecting cluster
cluster=$(cm_get "clusters" | grep "name" | sed -re "s/.*\"name\" : \"(.*)\".*/\1/")
url_cluster=$(echo "$cluster" | sed -re "s/ /%20/g")
echo "Detected '$cluster', for URL will use '$url_cluster'"

# Distributing parcel
cm_post clusters/$url_cluster/parcels/products/$product/versions/$version/commands/startDistribution
cm_wait_for_parcel clusters/$urlcluster/parcels/products/$produce/versions/$version DISTRIBUTED

# TODO: Activate parcel
# TODO: general clean up
