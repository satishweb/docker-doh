# DNS Over HTTP Service Docker Image (Compatible with Raspberry Pi)

## Overview

This Docker image provides a DNS Over HTTP (DOH) service, designed to enhance privacy and security by encrypting DNS queries. It supports custom upstream DNS servers and execution of custom scripts. The image is compatible with various architectures including linux/amd64, linux/arm64, and linux/arm/v7. It offers both Alpine and Ubuntu based images for flexibility.

## Upcoming Features

- Helm chart for Kubernetes deployments (current chart is usable but not tied to the latest version of DOH)
- Automated CI/CD using Github Actions
- Kubernetes deployment examples

## Features

- DNS Over HTTP support
- Custom upstream DNS server option
- Support for custom script execution (/app-config)
- Compatible with below architectures:
  - Alpine: linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/ppc64le,linux/s390x,linux/386
  - Ubuntu: linux/amd64,linux/arm/v7,linux/ppc64le,linux/s390x
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

## Docker Configuration

```yaml
version: '2.2'
networks:
  default:

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

## Pull Docker Hub Image

```bash
docker pull satishweb/doh-server
```

# Quick Setup Guide

Follow these steps to set up DOH Server on Linux, Mac, or Raspberry Pi in minutes using Docker Compose.

## Requirements

- Raspberry Pi/Linux/Mac with Docker preinstalled (Required)
- DNS Server Setup on AWS R53 (Other providers supported)
- AWS Access Key, Secret key, and R53 DNS Hosted Zone ID (for LetsEncrypt based auto installation of SSL Certs) (Optional)

## Steps

1. Download the latest release from [GitHub](https://github.com/satishweb/docker-doh/releases) to your server:

```bash
wget https://github.com/satishweb/docker-doh/archive/v2.3.7.zip
unzip v2.3.7.zip
cp -rf docker-doh-2.3.7/examples/docker-compose-doh-server doh-server
rm -rf v2.3.7.zip docker-doh-2.3.7
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

## IPV6 Support

Docker-compose configuration with IPV6 support will be added in the future.

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
