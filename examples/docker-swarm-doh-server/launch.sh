#!/bin/bash

osv=$(uname)

## Get the real script folder path
cd `dirname $0`
script=`basename $0`
# Iterate down a (possible) chain of symlinks
while [ -L "$script" ]
do
    script=`readlink $script`
    cd `dirname $script`
    script=`basename $script`
done
workDir=`pwd -P`
cd $workDir

stackName=dns

# Validations
[[ ! $1 ]] && echo "ERR: Service names must be given as parameter" && exit 1

servicesConfigFlags=""
services=""
for i in "$@"
do
  serviceConfigFile="services/$i/docker-service.yml"
  if [[ -f "$serviceConfigFile" ]]; then
    echo "INFO: Service: Adding $i"
    servicesConfigFlags+=" -c $serviceConfigFile"
    services+=" $i"
  else
    echo " ERR: Service: Invalid service $i"
    echo "               Missing $serviceConfigFile"
    exit 1
  fi
done

# If stack is not up, check for ports before starting
if [[ "$(docker stack ls|grep -e "^$stackName* *.*Swarm"|wc -l)" != "1" ]]; then 
  # check for systemd-resolved package. We can not run unbound with systemd-resolved
  if [[ "$(dpkg -l 2>&1|grep systemd-resolved|wc -l)" -gt "0" ]]; then
    echo "systemd-resolved package is installed on this system."
    echo "We can not have unbound installed here as systemd-resolved use 53 DNS port"
    echo "You can safely uninstall the package using command apt-get -y purge systemd-resolved"
    exit 1
  fi

  if [[ "$(netstat -nl|grep ".*:53.*LISTEN"|wc -l)" -gt "0" ]]; then
    echo "Port 53 is in use."
    echo "Please identify and stop the service using that port."
    echo "Command: netstat -nl"
    exit 1
  fi
fi

# Create data directories
for i in $services
do
  serviceConfigFile="services/$i/docker-service.yml"
  dirs=" $(grep -e "^ *- ../../data/" $serviceConfigFile|awk -F '[:]' '{print $1}'|sed 's/- //; s/ //g;s/^..\/..\///g'|tr '\n' ' ')"
  for d in $dirs; do [[ ! -d ${d} ]] && mkdir -p ${d} >/dev/null 2>&1; done
done

docker swarm init >/dev/null 2>&1
docker network create --driver overlay proxy >/dev/null 2>&1
docker stack deploy ${servicesConfigFlags} ${stackName}
