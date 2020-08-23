# Helm Chart for docker-doh

## Introduction

This [Helm](https://github.com/kubernetes/helm) chart installs [docker-doh](https://github.com/satishweb/docker-doh) in a Kubernetes cluster. Welcome to [contribute](CONTRIBUTING.md) to Helm Chart for docker-doh.

## Prerequisites

- Kubernetes cluster 1.10+
- Helm 2.8.0+

## Installation

### Package the chart

```bash
helm package --version 2.2.2 --app-version 2.2.2 --destination . doh-server
```

### Configure the chart

The following items can be set via `--set` flag during installation or configured by editing the `values.yaml` directly(need to download the chart first).

#### Configure doh-server

For enable ingress, the ingress controller must be installed in the Kubernetes cluster and a tls secret should be create.
The following table lists the configurable parameters of the Harbor chart and the default values.

| Parameter                                                                   | Description                                                                                                                                                                                                                                                                                                                                     | Default                         |
| --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| **env**                                                                  |
| `env.DEBUG` | Disblable (0) or Enable (1) DEBUG | 0 |
| `env.UPSTREAM_DNS_SERVER` | The upstream DNS server | udp:8.8.8.8:53 |
| `env.DOH_SERVER_TIMEOUT` | Timeout to upstream DNS server | 10 |
| `env.DOH_SERVER_TRIES` | DNS Request retry  | 3 |
| `env.DOH_SERVER_VERBOSE` | Disblable (false) or Enable (true) verbose server | false |
| **ingress**                                                                  |
| `ingress.enabled` | Disblable (false) or Enable (true) the ingress | false |
| `ingress.domainName` | The domain name that should be use to expose ingress | doh.your-domain.com |
| `ingress.annotations` | Nginx Ingress annotations |  |

### Install the chart

Exemple install the doh-server helm chart with a release name `my-release`:

helm 2:
```bash
helm install --name my-release \
--set env.UPSTREAM_DNS_SERVER="udp:8.8.8.4:53" \
--set ingress.enabled=true \
--set ingress.domainName=doh.my-domain.com \
./doh-server-2.2.2.tgz

```

## Uninstallation

To uninstall/delete the `my-release` deployment:

helm 2:
```bash
helm delete --purge my-release
```
