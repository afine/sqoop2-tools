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
echo "CONF_DIR: $CONF_DIR"

echo "Entire environment:"
env

# Defining variables expected in Sqoop 2 start scripts
export HADOOP_COMMON_HOME=$CDH_HADOOP_HOME
export HADOOP_HDFS_HOME=$CDH_HDFS_HOME
export HADOOP_YARN_HOME=$CDH_YARN_HOME
export HADOOP_MAPRED_HOME=$CDH_MR2_HOME

echo "Starting Sqoop 2 from: $SQOOP2_PARCEL_DIRNAME"
exec $SQOOP2_PARCEL_DIRNAME/bin/sqoop.sh server start