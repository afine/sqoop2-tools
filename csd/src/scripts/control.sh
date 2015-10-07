#!/bin/bash
##
# Licensed to Cloudera, Inc. under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  Cloudera, Inc. licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# for debugging
set -x

# For better debugging
echo ""
echo "Date: `date`"
echo "Host: `hostname -f`"
echo "Pwd: `pwd`"
echo "SQOOP_SERVER_EXTRA_LIB: $SQOOP_SERVER_EXTRA_LIB"
echo "CM_SQOOP_DATABASE_HOSTNAME: $CM_SQOOP_DATABASE_HOSTNAME"
echo "CONF_DIR: $CONF_DIR"

echo "Entire environment:"
env

# If we're starting the server, the variable "COMMAND" will be empty and instead $1 will be "server"
if [[ -z "$COMMAND" ]]; then
  export COMMAND=$1
fi

# Defining variables expected in Sqoop 2 scripts
export HADOOP_COMMON_HOME=$CDH_HADOOP_HOME
export HADOOP_HDFS_HOME=$CDH_HDFS_HOME
export HADOOP_YARN_HOME=$CDH_YARN_HOME
export HADOOP_MAPRED_HOME=$CDH_MR2_HOME
export SQOOP_CONF_DIR=$CONF_DIR

# We also need to create small oustanding file that will instruct Sqoop to use the file configuration provider
echo "sqoop.config.provider=org.apache.sqoop.core.PropertiesConfigurationProvider" > $SQOOP_CONF_DIR/sqoop_bootstrap.properties

# We need to finish Sqoop 2 configuration file sqoop.properties as CM is not generating final configuration
export CONF_FILE=$SQOOP_CONF_DIR/sqoop.properties

# JDBC Repository provider post-configuration
case $CM_SQOOP_DATABASE_TYPE in
  MySQL)
    export DB_HANDLER="org.apache.sqoop.repository.mysql.MySqlRepositoryHandler"
    export DB_JDBC_PREFIX="jdbc:mysql://"
    export DB_DRIVER="com.mysql.jdbc.Driver"
  break
  ;;
  PostgreSQL)
    export DB_HANDLER="org.apache.sqoop.repository.postgresql.PostgresqlRepositoryHandler"
    export DB_JDBC_PREFIX="jdbc:postgresql://"
    export DB_DRIVER="org.postgresql.Driver"
  break
  ;;
  Derby)
    export DB_HANDLER="org.apache.sqoop.repository.derby.DerbyRepositoryHandler"
    export DB_JDBC_PREFIX="jdbc:derby:"
    export DB_DRIVER="org.apache.derby.jdbc.EmbeddedDriver"
  break
  ;;
  *)
    echo "Unknown Database type: '$CM_SQOOP_DATABASE_TYPE'"
    exit
  ;;
esac
echo "org.apache.sqoop.repository.jdbc.handler=$DB_HANDLER" >> $CONF_FILE
echo "org.apache.sqoop.repository.jdbc.url=${DB_JDBC_PREFIX}${CM_SQOOP_DATABASE_HOSTNAME}" >> $CONF_FILE
echo "org.apache.sqoop.repository.jdbc.driver=${DB_DRIVER}" >> $CONF_FILE

# Hadoop configuration directory depends on where we're running from:
echo "org.apache.sqoop.submission.engine.mapreduce.configuration.directory=$CONF_DIR/yarn-conf/" >> $CONF_FILE

# Execute required action(s)
case $COMMAND in
  upgrade)
    echo "Starting Sqoop 2 upgrade tool"
    exec $SQOOP2_PARCEL_DIRNAME/bin/sqoop.sh tool upgrade
    ;;
  server)
    export JAVA_OPTS="-Dlog4j.configuration=file:$SQOOP_CONF_DIR/log4j.properties -Dlog4j.debug"
    echo "Starting Sqoop 2 from: $SQOOP2_PARCEL_DIRNAME"
    exec $SQOOP2_PARCEL_DIRNAME/bin/sqoop.sh server run
    ;;
  *)
    echo "Unknown command: $COMMAND"
    exit
    ;;
esac