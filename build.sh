#!/bin/bash
# Author: Satish Gaikwad <satish@satishweb.com>
# For manual push to docker hub, pass "manual" as 2nd parameter to this script

##############
## INIT
##############
sDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
image="satishweb/doh-server"

# Get params
buildType=$1
imgPush=$2

##############
## Functions
##############

# Usage function
usage() {
  echo "Usage: $0 <BuildType> <ImagePush> "
  echo "      BuildType: amd64|armv7  -- Optional (Def: amd64)"
  echo "      ImagePush: manual|auto -- Optional (Def: auto)"
  exit 1
}

# lets display usage and exit here if first parameter is help
[[ "$1" == "help" ]] && usage

# error check function
errCheck(){
  # $1 = errocode
  # $2 = msg
  # $3 = exit on fail
  if [ "$?" != "0" ]
    then
      echo "ERR| $2"
      # if $3 is set then exit with errorcode
      [[ $3 ]] && exit $1
  fi
}

# Docker Build function
dockerBuild(){
  # $1 = image type
  # $2 = "additional docker arguments"

  # Lets set appropriate tags based on buildType
  imageTag=${1}-latest
  dockerfile=Dockerfile_$1
  echo "INFO: Building $1 Image: $image:$imageTag ... (may take a while)"
  docker build . $2 -f $dockerfile -t $image:$imageTag
  errCheck "$?" "Docker Build failed" "exitOnFail"

  # Lets identify version and setup image tags
  dohVer="$(curl -s https://api.github.com/repos/m13253/dns-over-https/tags|jq -r '.[0].name')"

  # Lets set image version tag based on buildType
  verTag=${1}-$dohVer

  if [[ $dohVer == *.*.* ]]
    then
      echo "INFO: Creating tags..."
      docker tag $image $image:$verTag >/dev/null 2>&1
      errCheck "$?" "Tag creation failed"
    else
      echo "WARN: Could not determine awscli version, ignoring tagging..."
  fi

  # Lets create git tag and do checkin
  if [[ $dohVer == *.*.* ]]
    then
      echo "INFO: Creating/Updating git tag"
      git tag -d $verTag
      git push --delete origin $verTag
      git tag $verTag
      git push origin --tags
  fi
}

##############
## Validations
##############

! [[ "$buildType" =~ ^(amd64|armv7)$ ]] && buildType=amd64
! [[ "$imgPush" =~ ^(manual|auto)$ ]] && imgPush=auto

##############
## Main method
##############

# Head
echo "INFO: Build Type: $buildType"
echo "INFO: Image Push $imgPush"
echo "NOTE: Execute \"$0 help\" to know parameters list"
echo "------------------------------------------------"
# Lets do git pull
echo "INFO: Fetching latest codebase changes"
git checkout master
git pull

# Lets prepare docker image
echo "INFO: Removing all tags of image $image ..."
docker rmi -f $(docker images|grep "$image"|awk '{print $1":"$2}') >/dev/null 2>&1
dohVer="$(curl -s https://api.github.com/repos/m13253/dns-over-https/tags|jq -r '.[0].name')"
dockerBuild $buildType "--build-arg DOH_VERSION_LATEST=$dohVer"

# Lets do manual push to docker.
# To be used only if docker automated build process is failed
if [[ "$imgPush" == "manual" ]]
  then
    echo "INFO: Logging in to Docker HUB... (Interactive Mode)"
    docker login
    errCheck "$?" "Docker login failed..." "exitOnFail"
    echo "INFO: Pushing build to Docker HUB..."
    docker push $image
    errCheck "$?" "Docker push failed..." "exitOnFail"
fi
