# Sqoop 2 beta packaging scripts

Various helpful scripts to package and deploy Sqoop 2 "beta" (unofficial) bits to CDH clusters.

## parcel.sh

Script `parcel.sh` is responsible for creating parcels with Sqoop 2 bits that can be installed into Cloudera Manager. The sripts requires two arguments - `-r` with github repository (that will be cloned) and `-b` with branch name inside this repository. The script should work with both upstream (Apache) and downstream (cloudera) repositories and branches.

```bash
# Building parcels for upstream bits
./parcel.sh -r https://github.com/apache/sqoop.git -b sqoop2
```
