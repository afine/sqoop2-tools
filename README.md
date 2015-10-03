# Sqoop 2 beta packaging scripts

Various helpful scripts to package and deploy Sqoop 2 "beta" (unofficial) bits to CDH clusters.

## General flow

This section WILL describe the general flow one needs to generate and deploy Sqoop2 beta on given cluster.

## Individual scripts

This section describes individual scripts that are available in the repository

### parcel.sh

Script `parcel.sh` is responsible for creating parcels with Sqoop 2 bits that can be installed into Cloudera Manager. The sripts requires two arguments - `-r` with github repository (that will be cloned) and `-b` with branch name inside this repository. The script should work with both upstream (Apache) and downstream (cloudera) repositories and branches.

```bash
# Building parcels for upstream bits
./parcel.sh -r https://github.com/apache/sqoop.git -b sqoop2
```

### deploy-parcels.sh

Script `deploy-parcels.sh` takes generated parcels (by default from target/parcel_repo where `parcel.sh` will generate output) and uploads them to given CM host. After upload the new parcel is distributed and activated.

TODO: Add parameter list

```bash
# Deploy parcels to given CM instance
./parcel.sh -h cool.sever.somewhere.org
```
