# Docker Image for DNS Over HTTP Service (Works for Raspberry PI)

## Features
- DNS Over HTTP
- Custom upstream DNS server option
- Support for custom script execution (/app-config)
- Support for linux/amd64,linux/arm64,linux/arm/v7
- Alpine based tiny images
- A great example of full DOH Server setup using Docker Swarm

## Why?
- Protect yourself from ISP. They know too much about you as you are using their DNS servers.
- You dont want to use DOH services from DOH providers. (they are just replacing your ISP DNS service)
- https://www.netsparker.com/blog/web-security/pros-cons-dns-over-https/
- https://en.wikipedia.org/wiki/DNS_over_HTTPS

## How to use

```bash
docker run -itd --name doh-server \
    -p 8053:8053 \
    -e UPSTREAM_DNS_SERVER=udp:8.8.8.8:53 \
satishweb/doh-server
```

## Docker configuration:
```yaml
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
    depends_on:
      - unbound
```

## Build Docker image
```bash
docker build . --no-cache -t satishweb/doh-server
```
## Pull Docker Hub Image
```bash
docker pull satishweb/doh-server
```

# How to setup DOH Server on Linux/Mac/RaspberryPI in minutes:
## Using Docker Compose
### Requirements:
- RaspeberryPi/Linux/Mac with Docker preinstalled (Required)
- DNS Server Setup on AWS R53 (Other providers supported)
- AWS Access Key, Secret key and R53 DNS Hosted Zone ID (for LetsEncrypt based auto installation of SSL Certs) (Optional)

### Steps
- Visit https://github.com/satishweb/docker-doh/releases and download latest release to your server
```bash
wget https://github.com/satishweb/docker-doh/archive/v2.2.2.zip
unzip v2.2.2.zip
cp -rf docker-doh-2.2.2/examples/docker-compose-doh-server doh-server
rm -rf v2.2.2.zip docker-doh-2.2.2
cd doh-server
```
- Copy env.sample.conf to env.conf and update environment variables
```bash
EMAIL=user@example.com
DOMAIN=example.com
SUBDOMAIN=dns
AWS_ACCESS_KEY_ID=AKIKJ_CHANGE_ME_FKGAFVA
AWS_SECRET_ACCESS_KEY=Nx3yKjujG8kjj_CHANGE_ME_Z/FnMjhfJHFvEMRY3
AWS_REGION=us-east-1
AWS_HOSTED_ZONE_ID=Z268_CHANGE_ME_IQT2CE6
```
- Launch services
```bash
./launch.sh
```
- Add your custom hosts to override DNS records if needed.
```bash
mkdir -p data/unbound/custom
vi data/unbound/custom/custom.hosts
Contents:
local-zone: "SUB1.example.com" redirect
local-data: "SUB1.example.com A 192.168.0.100"
local-zone: "SUB2.example.com" redirect
local-data: "SUB2.example.com A 192.168.0.101"
```

- What is my DOH address?
```bash
https://dns.example.com/getnsrecord
```

- How do I test DoH Server?
```bash
curl -w '\n' 'https://dns.example.com/getnsrecord?name=google.com&type=A'
```

## Common Issues and how to debug them
- Proxy is still running with self signed certificate
  - Check data/proxy/certs/acme.json contents.
  - Enable debug mode for proxy by editing proxy service in docker-compose.yml. Run launch command again for changes to take effect.
  - Check proxy container logs for errors.

> Note: If you are using IAM account for R53 access, please make sure you have below permissions added in access policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "route53:GetChange",
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*",
        "arn:aws:route53:::change/*"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    }
  ]
}
```
- Can not bind 53 port for unbound service
  - Unbound service is configured to bind 53 port on the docker host.
  - Sometimes systemd-resolved service blocks that port and it needs to be stopped
  - run `sudo service systemd-resolved stop;sudo apt-get -y purge systemd-resolved` and then retry again
  - Unbound service port mappings can be commented out if DOH service is the only DNS client for it.

- Can not bind port 80 and 443 for proxy service.
  - Another program on the docker host or one of the docker container has aquired the same ports.
  - You need to stop those programs or change the proxy service ports to unused ports

## Using Docker Swarm

### Requirements
- RaspeberryPi/Linux/Mac with Docker preinstalled (Required)
- DNS Server Setup on AWS R53 (Optional)
- AWS Access Key, Secret key and R53 DNS Hosted Zone ID (for LetsEncrypt based auto installation of SSL Certs) (Optional)
- SSL Certificate (Required if your domain DNS hosting is not done at AWS)

### Steps
- Visit https://github.com/satishweb/docker-doh/releases and download latest release to your server
```bash
wget https://github.com/satishweb/docker-doh/archive/v2.2.2.zip
unzip v2.2.2.zip
cp -rf docker-doh-2.2.2/examples/docker-swarm-doh-server doh-server
rm -rf v2.2.2.zip docker-doh-2.2.2
cd doh-server
```

- Edit services/cert-manager/docker-service.yml and update below variables
> Note: This is to be done only if you intend to automatically setup SSL certificate using AWS DNS Hosting
```bash
DOMAIN_1
CERTBOT_EMAIL
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
AWS_HOSTED_ZONE_ID
```

- If you do not have AWS DNS Hosting, you need to add your SSL certificate manually
> Note: You need your SSL certificate, CA Certificates and Private Key to complete below SSL configuration. You may use letsencrypt to generate a free certificate.
```bash
mkdir -p data/proxy/certs
# Generate Certificate Chain using below command
cat your-ssl-certicate.pem your-ca-certificate.pem your-private-key.pem > data/proxy/certs/example.com.combined.pem
```

- Add your custom hosts to override DNS records if needed.
```bash
mkdir -p data/unbound
vi data/unbound/custom.hosts
Contents:
local-zone: "SUB1.example.com" redirect
local-data: "SUB1.example.com A 192.168.0.100"
local-zone: "SUB2.example.com" redirect
local-data: "SUB2.example.com A 192.168.0.101"
```

- Start DNS server with Auto SSL Cert generation using LetsEncrypt and AWS DNS Hosting
```bash
./launch.sh unbound cert-manager proxy swarm-listener doh-server
```

- Start DNS Server with custom SSL certificate
```bash
./launch.sh unbound proxy swarm-listener doh-server
```

- Stop DNS Server:
```bash
./remove.sh
```

- How to check if all is running well?
```bash
docker service ls
```

- How to see logs of service?
```bash
docker service logs -f dns_unbound
```

- What is my DOH address?
```bash
https://dns.example.com/getnsrecord
```

- How do I test DoH Server?
```bash
curl -w '\n' 'https://dns.example.com/getnsrecord?name=google.com&type=A'
```

## IPV6 Support
- Docker compose/Swarm configuration with IPV6 support will be added in future.

# How to use DOH Server?
## Setup your Router (Best experience)
- Login to your router and search for DHCP settings
- Setup DNS settings to the IP of your DOH server.
> Note: This will make all your client systems/phones connected to your router use this your DNS server.
> Note: This will not make clients use DOH but it will end up using unbound private DNS service that protects you from ISP.

## Linux, Mac, Windows Clients
- Install Cloudflared for Linux, Mac, Windows using below link
```bash
https://developers.cloudflare.com/argo-tunnel/downloads/
```
- Set your DOH server as upstream for cloudflared with below configuration
  - Linux: /usr/local/etc/cloudflared/config.yml
  - Mac: /usr/local/etc/cloudflared/config.yaml
  - Windows: God knows where, I don't have windows

```yaml
proxy-dns: true
proxy-dns-upstream:
 - https://dns.example.com/getnsrecord
```
> Note: You will need to ensure dnsmasq is uninstalled from your client system before using cloudflared

## Android
- Install Infra app from Play Store
```bash
https://play.google.com/store/apps/details?id=app.intra&hl=en_US
```

- Configure infra app to use your DOH server
```
Infra App -> Settings -> Select DNS over HTTPS Server -> Custom server URL
Value: https://dns.example.com/getnsrecord
```

# Credits
- DOH Server: https://github.com/m13253/dns-over-https
- Docker Flow Proxy: https://proxy.dockerflow.com/
- Traefik Proxy: https://www.traefik.io
