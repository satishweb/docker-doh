#!/bin/bash

__findWorkDir() {
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
}

envsubst() {
  # $1 = Source file path
  # $2 = Destination file path
  if [ "$2" = "" ]; then
    echo "ERR: envsubst function called without parameters"
    exit 1
  fi
  DOLLAR='$'
  cp $1 $2
  sed ${sedFlags} 's/\\/\\\\/g;s/"/\\"/g;s/`/BACKQUOTE/g' $2
  sed ${sedFlags} '' $2
  eval "echo \"$(cat $2)\"" > $2
  sed ${sedFlags} 's/BACKQUOTE/`/g' $2
}

__loadConfig() {
  # env.conf is needed
  if [[ ! -f env.conf ]]; then
    echo "ERR: env.conf is missing"
    echo "     Please copy env.sample.conf to env.conf"
    echo "     and update variable values before running launch script"
    exit 1
  fi

  while read -r line
  do
    if [[ "$line" != "" && "$line" =~ = && ! "$line" =~ ^#.* ]]; then
      varName=$(echo $line|awk -F '[=]' '{print $1}')
      varValue=$(echo $line|sed "s/^${varName}=//")
      export ${varName}="${varValue}"
    fi
  done <<< "$(cat env.conf)"
}

__validations() {

  export osv=$(uname|awk '{ print $1 }')
  if [[ "$osv" == "Darwin" ]]; then
      sedFlags="-i '' "
  else
      sedFlags="-i "
  fi

  # If stack is not up, check for ports before starting
  if [[ "$(docker ps --format '{{.Names}}'|grep -e "${STACK}_*"|wc -l)" -lt "1" ]]; then 
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
  mkdir -p data/unbound/custom/
  sudo touch data/unbound/custom/custom.hosts

  # Cleanup exited containers
  # Warn: This will clean non related but exited containers as well.
  docker rm $(docker ps -q -f "status=exited") >/dev/null 2>&1
}

__launchDockerContainers() {
  set -e

  envsubst "docker-compose.yml" ".local-docker-compose.yml"
  docker-compose -f .local-docker-compose.yml -p ${STACK} up -d
  if [[ "$?" != "0" ]]; then
    echo "Docker compose command failed"
    exit 1
  else
    echo "Docker compose has launched services. Please check container logs"
  fi
}

# Main

__findWorkDir
__loadConfig
__validations
__launchDockerContainers
