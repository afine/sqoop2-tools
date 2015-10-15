# Sqoop 2 beta packaging scripts

Various helpful scripts to package and deploy arbitrary Sqoop 2 repository to CDH cluster (with associated CM service).

## Sqoop 2 beta packaging scripts

Various helpful scripts to package and deploy arbitrary Sqoop 2 repository to CDH cluster (with associated CM service).

## Dependencies

These are some additional tools that need to be installed to run these scripts
under OS X 10.11.
### sha1sum
`brew install md5sha1sum`
### sshpass
`brew install http://git.io/sshpass.rb`
### sed (the gnu version)
`brew install gnu-sed --with-default-names`


## General flow

The general flow is as follows:

1. Generate parcel (=package) for given repository and branch
2. Upload (deploy) the generated parcel to given CM instance
3. Upload (deploy) CSD to given CM instance
4. Create Sqoop 2 service in given CM instance

```bash
# Building parcels for upstream bits
./parcel.sh -r https://github.com/apache/sqoop.git -b sqoop2
./deploy-parcels.sh -h cool.sever.somewhere.org
./deploy-csd.sh -h cool.sever.somewhere.org
./deploy-service.sh -h cool.sever.somewhere.org
```

You still need to CM to deploy the Sqoop 2 service on the cluster as this step hasn't been automated yet.

## Individual scripts

This section describes individual scripts that are available in the repository

### `parcel.sh`

Script `parcel.sh` is responsible for creating parcels with Sqoop 2 bits that can be installed into Cloudera Manager and subsequently distributed across the cluster. The sripts requires two arguments - `-r` with github repository (that will be cloned to working directory) and `-b` with branch name inside this repository. The script should work with both upstream (Apache) and downstream (cloudera) repositories and branches (provided all dependent patches are available there).

```bash
# Building parcels for upstream bits
./parcel.sh -r https://github.com/apache/sqoop.git -b sqoop2
```

All parameters:

* `-r` Repository URL (anything that `git clone` will accept)
* `-b` Branch in the repository that we'll use to generate the parcels

### `deploy-parcels.sh`

Script `deploy-parcels.sh` takes generated parcels (by default from `target/parcel_repo` where script `parcel.sh` will generate output) and uploads them to given CM host. After upload the new parcel is distributed and activated.

```bash
# Deploy parcels to given CM instance
./deploy-parcels.sh -h cool.sever.somewhere.org
```

All parameters:

* `-p` Local parcel repository (default is `target/parcel_repo`)
* `-t` Target directory on CM server host where the parcel(s) should be uploaded (default is `/opt/cloudera/parcel-repo`)
* `-u` Username for SSH access to CM server (default is `root`)
* `-w` Password for SSH access to CM server (default is `cloudera`)
* `-h` Hostname of CM server
* `-c` Curl compatible login information for CM server (default is `admin:admin`)

### `deploy-csd.sh`

Script `deploy-csd.sh` will build CSD (Custom service descriptor, code for Cloudera Manager to actually manage the Sqoop 2 service) and deploy it to target CM host. This script will restart CM to force CM to load the CSD jar.

```bash
# Deploy CSD to given CM instance
./deploy-csd.sh -h cool.sever.somewhere.org
```

All parameters:

* `-t` Target directory on CM server host where the CSD should be uploaded (default is `/opt/cloudera/csd`)
* `-u` Username for SSH access to CM server (default is `root`)
* `-w` Password for SSH access to CM server (default is `cloudera`)
* `-h` Hostname of CM server
* `-c` Curl compatible login information for CM server (default is `admin:admin`)

### `deploy-service.sh`

Script `deploy-csd.sh` deploy Sqoop 2 service in given CM server. If service of given name already exists, we'll drop it and re-create it again.

```bash
# Create service
./deploy-service.sh -h cool.sever.somewhere.org
```

All parameters:

* `-u` Username for SSH access to CM server (default is `root`)
* `-w` Password for SSH access to CM server (default is `cloudera`)
* `-h` Hostname of CM server
* `-c` Curl compatible login information for CM server (default is `admin:admin`)
* `-n` Name for the deployed service (default is `Sqoop-2-beta`)
* `-s` Hostname where the Sqoop 2 Server should be deployed (default is the same value as has been used for `-h`)
* `-y` Name of YARN service that should be used as dependency for newly deployed service (default is 1st YARN service available on the cluster)
