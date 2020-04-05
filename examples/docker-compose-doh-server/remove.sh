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
    if [[ ! -f .local-docker-compose.yml ]]; then
        echo "ERR: .local-docker-compose.yml is missing, possible that services were never launched"
    fi
}
__removeDockerContainers() {
    docker-compose -f .local-docker-compose.yml -p ${STACK} down
}

__findWorkDir
__loadConfig
__validations
__removeDockerContainers