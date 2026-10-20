# DNS Over HTTP Service Docker Image (Compatible with Raspberry Pi)

## Overview

This Docker image provides a DNS Over HTTP (DOH) service, designed to enhance privacy and security by encrypting DNS queries. It supports custom upstream DNS servers and execution of custom scripts. The image is compatible with various architectures including linux/amd64, linux/arm64, and linux/arm/v7. It offers both Alpine and Ubuntu based images for flexibility.

The image is a thin wrapper around the upstream project
[m13253/dns-over-https](https://github.com/m13253/dns-over-https). The upstream
release that is compiled into the image is pinned in the `DOH_VERSION` build
argument and defaults to **v2.3.10**.

## Features

- DNS Over HTTP support (RFC 8484 wireformat and the Google JSON API)
- Custom upstream DNS server option, multiple servers are supported
- Support for custom script execution (/app-config)
- Support for Docker / Swarm secrets
- Support for a custom configuration file
- Compatible with below architectures:
  - Alpine: linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/ppc64le,linux/s390x,linux/386,linux/riscv64
  - Ubuntu: linux/amd64,linux/arm64,linux/arm/v7,linux/ppc64le,linux/s390x
- Alpine based tiny images; Ubuntu based image also available
- Comprehensive DOH Server setup example using Docker Compose

## Why Use DNS Over HTTP?

Using DNS Over HTTP offers several advantages:

- Protects against ISP monitoring
- Avoids reliance on DOH providers, preserving privacy
- Learn more: [Pros & Cons of DNS Over HTTPS](https://www.netsparker.com/blog/web-security/pros-cons-dns-over-https/)
- Additional resource: [DNS over HTTPS - Wikipedia](https://en.wikipedia.org/wiki/DNS_over_HTTPS)

## How to Use

```bash
docker run -itd --name doh-server \
    -p 8053:8053 \
    -e UPSTREAM_DNS_SERVER=udp:208.67.222.222:53 \
    satishweb/doh-server
```

## Configuration

The container is configured entirely through environment variables. They are
substituted into `/server/doh-server.sample.conf` to generate
`/server/doh-server.conf` at startup.

| Variable | Default | Description |
| --- | --- | --- |
| `UPSTREAM_DNS_SERVER` | `udp:208.67.222.222:53,udp:208.67.220.220:53` | Upstream resolver(s), comma separated. Prefix is `udp`, `tcp` or `tcp-tls`. A random server is picked for every attempt. |
| `DOH_HTTP_PREFIX` | `/getnsrecord` | HTTP path of the resolve endpoint. |
| `DOH_SERVER_LISTEN` | `:8053` | Listen address of the HTTP server. |
| `DOH_SERVER_TIMEOUT` | `10` | Upstream timeout in seconds. |
| `DOH_SERVER_TRIES` | `3` | Number of attempts per query. |
| `DOH_SERVER_VERBOSE` | `false` | Enable query logging. |
| `DOH_SERVER_LOG_GUESSED_CLIENT_IP` | `false` | Log the client IP taken from `X-Forwarded-For` / `X-Real-IP`. |
| `DOH_SERVER_ECS_ALLOW_NON_GLOBAL_IP` | `false` | Allow EDNS Client Subnet for non global (private) client IPs. |
| `DOH_SERVER_ECS_USE_PRECISE_IP` | `false` | Use the full client IP for EDNS Client Subnet instead of a /24 or /56 mask. |
| `DEBUG` | `0` | Set to `1` to trace the entrypoint script. |

Empty values are replaced by the defaults above, so an unset variable never
makes the container fail to start.

### The HTTP path

The default path `/getnsrecord` is not the path that browsers and operating
systems use by default. Chrome, Firefox, cloudflared and most other clients
expect the RFC 8484 path `/dns-query`. Either set `DOH_HTTP_PREFIX=/dns-query`
or configure the path on the client side.

### Custom configuration file

Mount your own configuration to replace the generated one completely. The file
is used **as is**, no variable substitution is applied to it:

```yaml
    volumes:
      - ./doh-server.conf:/server/doh-server.conf
```

The supported options are defined by the upstream project, see
[`doh-server/config.go`](https://github.com/m13253/dns-over-https/blob/master/doh-server/config.go).
The upstream server refuses to start when it encounters an unknown option.

### Docker secrets

Any variable that is referenced through a `<NAME>_FILE` environment variable is
read from that file and exported. This works with Docker Compose `secrets:` and
with Docker Swarm secrets:

```yaml
services:
  doh-server:
    image: satishweb/doh-server
    environment:
      UPSTREAM_DNS_SERVER_FILE: /run/secrets/UPSTREAM_DNS_SERVER
    secrets:
      - UPSTREAM_DNS_SERVER
```

Secret values are read verbatim, values containing whitespace or shell
metacharacters are preserved. The resolved values are written to
`/tmp/doh-secrets.env` inside the container for troubleshooting.

## Docker Configuration

```yaml
services:
  doh-server:
    image: satishweb/doh-server
    hostname: doh-server
    networks:
      - default
    environment:
      DEBUG: "0"
      # Upstream DNS server: proto:host:port
      # We are using OpenDNS DNS servers as default,
      # Here is the list of addresses: https://use.opendns.com/
      UPSTREAM_DNS_SERVER: "udp:208.67.222.222:53"
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
```

## Docker Buildx Setup

### Setup: Mac M1/x86

```bash
brew install colima
colima start --cpu 8 --memory 16 --disk 150
docker context use colima
```

### Setup: Mac M1 (buildx)

```bash
brew install colima
colima start --arch x86_64 --cpu 8 --memory 16 --disk 150 -p buildx
docker context use colima-buildx
```

### Setup: Linux

- Install Docker CLI + Containerd
- Install docker-compose

### Start Buildx instance

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx create --use
docker buildx inspect --bootstrap
```

## Build Docker Image

```bash
docker build . --no-cache -t satishweb/doh-server -f Dockerfile.alpine
```

To build a different upstream release:

```bash
docker build . --build-arg DOH_VERSION=v2.3.10 -t satishweb/doh-server -f Dockerfile.alpine
```

The build fails if the version of the downloaded source does not match the
requested one, so a wrong or truncated download can not slip through.

## Pull Docker Hub Image

```bash
docker pull satishweb/doh-server
```

# Quick Setup Guide

Follow these steps to set up DOH Server on Linux, Mac, or Raspberry Pi in minutes using Docker Compose.

## Requirements

- Raspberry Pi/Linux/Mac with Docker preinstalled (Required)
- Docker Compose v2 (`docker compose`) (Required)
- DNS Server Setup on AWS R53 (Other providers supported)
- AWS Access Key, Secret key, and R53 DNS Hosted Zone ID (for LetsEncrypt based auto installation of SSL Certs) (Optional)

## Steps

1. Download the latest release from [GitHub](https://github.com/satishweb/docker-doh/releases) to your server:

```bash
wget https://github.com/satishweb/docker-doh/archive/v2.3.10.zip
unzip v2.3.10.zip
cp -rf docker-doh-2.3.10/examples/docker-compose-doh-server doh-server
rm -rf v2.3.10.zip docker-doh-2.3.10
cd doh-server
```

2. Copy `env.sample.conf` to `env.conf` and update environment variables:

```bash
EMAIL=user@example.com
DOMAIN=example.com
SUBDOMAIN=dns
AWS_ACCESS_KEY_ID=AKIKJ_CHANGE_ME_FKGAFVA
AWS_SECRET_ACCESS_KEY=Nx3yKjujG8kjj_CHANGE_ME_Z/FnMjhfJHFvEMRY3
AWS_REGION=us-east-1
AWS_HOSTED_ZONE_ID=Z268_CHANGE_ME_IQT2CE6
```

3. Launch services:

```bash
./launch.sh
```

4. Add your custom hosts to override DNS records if needed:

```bash
mkdir -p data/unbound/custom
vi data/unbound/custom/custom.hosts
```

5. Determine your DOH address:

```bash
https://dns.example.com/getnsrecord
```

6. Test the DOH Server:

```bash
curl -w '\n' 'https://dns.example.com/getnsrecord?name=google.com&type=A'
```

## Common Issues and Debugging

- If a proxy is still running with a self-signed certificate:
  - Check `data/proxy/certs/acme.json` contents.
  - Enable debug mode for the proxy by editing the proxy service in `docker-compose.yml`.
  - Check proxy container logs for errors.

- If unable to bind port 53 for unbound service:
  - Stop `systemd-resolved` service: `sudo service systemd-resolved stop; sudo apt-get -y purge systemd-resolved`
  - Retry.

- If unable to bind ports 80 and 443 for proxy service:
  - Another program on the Docker host or one of the Docker containers may be using the same ports.
  - Stop those programs or change the proxy service ports to unused ports.

- If the container exits right away with a message about the upstream:
  - The upstream resolver list is invalid. Every entry needs a `udp`, `tcp` or
    `tcp-tls` prefix, e.g. `udp:1.1.1.1:53`.

## Health Check

The image ships with a health check that queries the local server. The check
passes when the server answers with `200` or `503`, so a broken upstream
resolver does not make the container look unhealthy (and does not cause a
restart loop in an orchestrator).

## Security Notes

The upstream server answers with `Access-Control-Allow-Origin: *`, which is
required by the browser based DoH clients but also means that **any website can
use your DoH server as a DNS proxy**. When the DoH server points at a private
resolver this turns it into an open relay into your network.

Always run the DoH server behind a reverse proxy that applies rate limiting.
The provided compose example does this with the Traefik rate limit middleware.

## IPV6 Support

Set `IPV6=true` in `env.conf` before running `./launch.sh`. The launch script
then adds `docker-compose-ipv6.yml` to the compose invocation, which enables
IPv6 on the docker network. The docker daemon needs to be started with
`ipv6 = true` in `/etc/docker/daemon.json` for dual stack networks.

# How to Use DOH Server?

## Setup Your Router (Recommended)

Configure your router's DHCP settings to point to your DOH server's IP address.

## Linux, Mac, Windows Clients

Install Cloudflared for Linux, Mac, or Windows. Set your DOH server as upstream for Cloudflared as follows:

- Linux: `/usr/local/etc/cloudflared/config.yml`
- Mac: `/usr/local/etc/cloudflared/config.yaml`
- Windows: Location varies

```yaml
proxy-dns: true
```

## Kubernetes

A Helm chart is available in the `helm` directory:

```bash
helm install doh-server ./helm/doh-server --set env.UPSTREAM_DNS_SERVER="udp:8.8.8.8:53"
```
