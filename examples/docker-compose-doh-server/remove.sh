#!/bin/bash


__findWorkDir() {
  ## Get the real script folder path
  cd "$(dirname "$0")" || exit 1
  script=$(basename "$0")
  # Iterate down a (possible) chain of symlinks
  while [ -L "$script" ]
  do
      script=$(readlink "$script")
      cd "$(dirname "$script")" || exit 1
      script=$(basename "$script")
  done
  workDir=$(pwd -P)
  cd "$workDir" || exit 1
}

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
    fi
  done <<< "$(cat env.conf)"
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
    exit 1
  fi
}

__validations() {
    if [[ ! -f .local-docker-compose.yml ]]; then
        echo "ERR: .local-docker-compose.yml is missing, possible that services were never launched"
        exit 1
    fi
}

__removeDockerContainers() {
    local compose
    compose=$(__composeCmd)
    local composeFiles=("-f" ".local-docker-compose.yml")
    if [[ -f .local-docker-compose-ipv6.yml ]]; then
      composeFiles+=("-f" ".local-docker-compose-ipv6.yml")
    fi
    ${compose} "${composeFiles[@]}" -p "${STACK}" down --remove-orphans
}

__findWorkDir
__loadConfig
__validations
__removeDockerContainers
