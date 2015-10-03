#!/bin/bash
# Create parcel for given repository

# Working properties
repository=''
branch=''
workdir='target'
pwd=`pwd`

# Argument parsing
while getopts "r:b:w:" optname ; do
  case "$optname" in
    "r")
      repository=$OPTARG
      ;;
    "b")
      branch=$OPTARG
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
if [[ -z $repository ]]; then
  echo "Missing argument -r with repository location"
  exit 1
fi
if [[ -z $branch ]]; then
  echo "Missing argument -b with branch name"
  exit 1
fi

# Work itself
echo "Repository: $repository"
echo "Branch: $branch"
echo "Workdir: $workdir"

mkdir -p $workdir

repository_dir=`md5sum <<< $repository`
repository_dir="$workdir/repo_${repository_dir:1:20}"
echo "Repository directory: $repository_dir"

# Create directory if it doesn't exist, otherwise just fetch origin
if [[ -d $repository_dir ]]; then
  cd $repository_dir
  git fetch
else
  git clone $repository $repository_dir
  cd $repository_dir
fi

# Some branch magic
git checkout $branch
git pull

# Build binary archive of the project
mvn clean package -Pbinary -DskipTests

# Get to original location
cd $pwd

# Detect version
product_version=`grep "<version>" $repository_dir/pom.xml | head -n 2 | tail -n 1 | sed -re "s/^.*>(.*)<.*$/\1/"`
echo "Detected product version: $product_version"

# We want to enhance product version with timestamp as we're likely to generate many parcels for the same version in working environment
version="`date +%Y%m%d%H%M`-$product_version"
echo "Final version: $version"

# Parcel directory
parcel_dir=$workdir/SQOOP2_BETA-$version
echo "Parcel directory: $parcel_dir"
rm -rf $parcel_dir
mkdir -p $parcel_dir

# Fill it with basic data from upstram distribution tarball
mv $repository_dir/dist/target/sqoop*/* $parcel_dir/
rm -rf $parcel_dir/meta
mkdir -p $parcel_dir/meta

# We need to create all various distributions
for distro in el5 el6 el7 precise sles11 trusty wheezy; do
  echo "Creating parcel for $distro"
  # Clean up meta every time
  rm -rf $parcel_dir/meta
  mkdir -p $parcel_dir/meta

  # Meta file
  cp parcel/* $parcel_dir/meta
  sed -i -e "s/##VERSION##/$version/g" $parcel_dir/meta/parcel.json

  # Creating target parcel archive
  cd $workdir
  tar -cvzf SQOOP2_BETA-$version-$distro.parcel SQOOP2_BETA-$version
  cd $pwd
done

# Generating parcel repository
parcel_repo=$workdir/parcel_repo
rm -rf $parcel_repo
mkdir -p $parcel_repo
mv $workdir/*parcel $parcel_repo
manifest=$parcel_repo/manifest.json

echo "Generating parcel repository in: $parcel_repo"
echo '{' > $manifest
echo "  \"lastUpdated\" : `date +%s`0000," >> $manifest
echo "  \"parcels\": [" >> $manifest
first=YES
for filepath in $parcel_repo/*.parcel; do
  file=$(basename $filepath)
  echo "Adding parcel $file on path $filepath"

  if [[ $first = "YES" ]]; then
    first=NO
  else
    echo "  ," >> $manifest
  fi

  echo "  {" >> $manifest
  echo "    \"parcelName\": \"$file\"," >> $manifest
  echo "    \"hash\": \"`sha1sum $filepath | cut -f1 -d' '`\"," >> $manifest
  echo "    \"components\": []" >> $manifest
  echo "  }" >> $manifest
done
echo " ]" >> $manifest
echo '}' >> $manifest
