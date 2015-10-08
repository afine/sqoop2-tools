#!/bin/bash
# Deploy CSD to CM

# Working properties
target_dir='/opt/cloudera/csd/'
host=''
username='root'
password='cloudera'
workdir='target/'
pwd=`pwd`

# Argument parsing
while getopts "t:u:w:h:" optname ; do
  case "$optname" in
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
echo "Target directory: $target_dir"
echo "Host: $host"
echo "Username: $username"
echo "Password: $password"

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
  curl -sS -X $1 -u "admin:admin" -i "http://${host}:7180/api/v8/$2" 2>&1
}
function cm_get() {
  cm_api "GET" "$1"
}
function cm_post() {
  cm_api "POST" "$1" > /dev/null
}

# Wait until parcel will get to given state
function cm_wait_for_load () {
  while [ 1 ]
  do
    # Call echo service (should return back what we send there)
    output=$(cm_get /tools/echo?message=Started)

    # Ignore any "connection refused" commit from curl though
    message=`echo $output | grep -v  "Connection refused" | grep message | sed -re "s/^.* \"message\" : \"([A-Z]+)\".*\$/\1/"`

    # Breaking condition
    echo $message | grep "Started" > /dev/null && break

    # To keep us informed
    echo "Waiting on CM server to start up"
    sleep 5
  done
}

# Build local CSD (stored in csd folder)
cd csd
echo "Building CSD archive"
mvn clean package -DskipTests
cd $pwd

echo "Uploading CSD to CM server"
remote_copy csd/target/SQOOP2_BETA*.jar $target_dir

echo "Restartin CM server to load new CSD version"
remote_exec "/etc/init.d/cloudera-scm-server restart"
cm_wait_for_load
