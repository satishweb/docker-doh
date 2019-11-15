# Docker Image for DNS Over HTTP Service

## Features
- DNS Over HTTP
- Custom upstream DNS server option
- Support for custom script execution (/app-config)

## How to use

```
docker run -itd --name doh-server \
    -p 8053:8053 \
    -e UPSTREAM_DNS_SERVER=udp:8.8.8.8:53 \
satishweb/doh-server
```

## Docker Stack configuration:
```
services:
  doh-server:
    image: satishweb/doh-server
    hostname: doh-server
    networks:
      - default
    environment:
      DEBUG: "0"
      UPSTREAM_DNS_SERVER: "udp:unbound:53"
      DOH_HTTP_PREFIX: "/getnsrecord"
      DOH_SERVER_LISTEN: ":8053"
      DOH_SERVER_TIMEOUT: "10"
      DOH_SERVER_TRIES: "3"
      DOH_SERVER_VERBOSE: "true"
      # You can add more variables here or as docker secret and entrypoint
      # script will replace them inside doh-server.conf file
    volumes:
      # - ./doh-server.conf:/server/doh-server.conf
      # Mount app-config script with your customizations
      # - ./app-config:/app-config
    deploy:
      replicas: 1
      # placement:
      #   constraints:
      #     - node.labels.type == worker
      restart_policy: *default-restart-policy
    depends_on:
      - unbound
    labels:
      - "com.satishweb.description=DNS Over HTTP Service"
```
>Note: For complete services stack please visit: TBA

## Build Docker image
```
docker build . --no-cache -t satishweb/doh-server
```
## Pull Docker Hub Image
```
docker pull satishweb/doh-server
```

## Credits
- DOH Server: https://github.com/m13253/dns-over-https