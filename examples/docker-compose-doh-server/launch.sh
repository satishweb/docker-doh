#!/bin/bash

__findWorkDir() {
  ## Get the real script folder path
  cd "$(dirname "$0")"
  script=$(basename "$0")
  # Iterate down a (possible) chain of symlinks
  while [ -L "$script" ]
  do
      script=$(readlink "$script")
      cd "$(dirname "$script")"
      script=$(basename "$script")
  done
  workDir=$(pwd -P)
  cd "$workDir"
}

# Names of the variables that were read from env.conf. Only these are
# substituted into the compose file, everything else is left untouched.
__configVars=()

__loadConfig() {
  # env.conf is needed
  if [[ ! -f env.conf ]]; then
    echo "ERR: env.conf is missing"
    echo "     Please copy env.sample.conf to env.conf"
    echo "     and update variable values before running launch script"
    exit 1
  fi

  local line varName varValue
  while read -r line
  do
    if [[ "$line" != "" && "$line" =~ = && ! "$line" =~ ^#.* ]]; then
      varName=$(echo "$line"|awk -F '[=]' '{print $1}')
      varValue="${line#"${varName}"=}"
      export "${varName}=${varValue}"
      __configVars+=("${varName}")
    fi
  done <<< "$(cat env.conf)"
}

# Substitute the variables of env.conf into a template file.
# This is a safe replacement: the values are inserted literally, no shell
# evaluation takes place and unknown $placeholders are left untouched.
__renderTemplate() {
  # $1 = Source file path
  # $2 = Destination file path
  if [ "$2" = "" ]; then
    echo "ERR: renderTemplate called without parameters"
    exit 1
  fi
  local content varName varValue
  content=$(cat "$1")
  for varName in "${__configVars[@]}"; do
    varValue="${!varName}"
    content="${content//\$\{$varName\}/$varValue}"
    content="${content//\$$varName/$varValue}"
  done
  printf '%s\n' "$content" > "$2"
}

# Docker Compose v2 ("docker compose") is the supported one, fall back to the
# legacy v1 binary when it is not available.
__composeCmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    echo "ERR: docker compose is not installed."
    echo "     Please install Docker Compose v2: https://docs.docker.com/compose/install/"
    exit 1
  fi
}

# Check whether the given TCP/UDP port is already in use.
__isPortInUse() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -lntu 2>/dev/null | awk '{print $5}' | grep -qE "[:.]${port}\$"
  elif command -v netstat >/dev/null 2>&1; then
    netstat -lntu 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}\$"
  else
    return 1
  fi
}

__isTrue() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

__validations() {

  export osv
  osv=$(uname|awk '{ print $1 }')

  # If stack is not up, check for ports before starting
  if [[ "$(docker ps --format '{{.Names}}'|grep -c -e "${STACK}_*")" -lt "1" ]]; then
    # check for systemd-resolved package. We can not run unbound with systemd-resolved
    if [[ "$(dpkg -l 2>&1|grep -c systemd-resolved)" -gt "0" ]]; then
      echo "systemd-resolved package is installed on this system."
      echo "We can not have unbound installed here as systemd-resolved use 53 DNS port"
      echo "You can safely uninstall the package using command apt-get -y purge systemd-resolved"
      exit 1
    fi

    if __isPortInUse 53; then
      echo "Port 53 is in use."
      echo "Please identify and stop the service using that port."
      echo "Command: netstat -nl"
      exit 1
    fi
  fi

  # Create data directories
  mkdir -p data/unbound/custom/
  if [ ! -f data/unbound/custom/custom.hosts ]; then
    touch data/unbound/custom/custom.hosts
  fi

  # Cleanup exited containers of this stack only.
  # Containers of other projects are left untouched.
  local staleContainers=()
  mapfile -t staleContainers < <(docker ps -q -f "status=exited" -f "label=com.docker.compose.project=${STACK}" 2>/dev/null)
  if [ ${#staleContainers[@]} -gt "0" ]; then
    docker rm -f "${staleContainers[@]}" >/dev/null 2>&1
  fi
}

__launchDockerContainers() {
  set -e

  local composeFiles=("-f" ".local-docker-compose.yml")
  if __isTrue "${IPV6}"; then
    echo "INFO: IPv6 support is enabled"
    __renderTemplate "docker-compose-ipv6.yml" ".local-docker-compose-ipv6.yml"
    composeFiles+=("-f" ".local-docker-compose-ipv6.yml")
  fi

  __renderTemplate "docker-compose.yml" ".local-docker-compose.yml"

  local compose
  compose=$(__composeCmd)
  if ! ${compose} "${composeFiles[@]}" -p "${STACK}" up -d; then
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
