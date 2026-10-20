# Helm Chart for docker-doh

## Introduction

This [Helm](https://github.com/kubernetes/helm) chart installs [docker-doh](https://github.com/satishweb/docker-doh) in a Kubernetes cluster. Welcome to [contribute](CONTRIBUTING.md) to Helm Chart for docker-doh.

## Prerequisites

- Kubernetes cluster 1.19+
- Helm 3.0.0+

## Installation

### Package the chart

```bash
helm package --version 2.3.10 --app-version v2.3.10 --destination . doh-server
```

### Configure the chart

The following items can be set via `--set` flag during installation or configured by editing the `values.yaml` directly (need to download the chart first).

#### Configure doh-server

For enabling ingress, the ingress controller must be installed in the Kubernetes cluster and a tls secret should be created.

The following table lists the configurable parameters of the chart and the default values.

| Parameter | Description | Default |
| --- | --- | --- |
| **env** | | |
| `env.DEBUG` | Disable (0) or enable (1) DEBUG | 0 |
| `env.UPSTREAM_DNS_SERVER` | The upstream DNS server(s), comma separated | udp:8.8.8.8:53 |
| `env.DOH_HTTP_PREFIX` | The HTTP path of the resolve endpoint | /dns-query |
| `env.DOH_SERVER_LISTEN` | The listen address of the HTTP server | :8053 |
| `env.DOH_SERVER_TIMEOUT` | Timeout to upstream DNS server | 10 |
| `env.DOH_SERVER_TRIES` | DNS Request retry | 3 |
| `env.DOH_SERVER_VERBOSE` | Disable (false) or enable (true) verbose server | false |
| `env.DOH_SERVER_LOG_GUESSED_CLIENT_IP` | Log the client IP from the reverse proxy headers | false |
| `env.DOH_SERVER_ECS_ALLOW_NON_GLOBAL_IP` | Allow EDNS Client Subnet for private client IPs | false |
| `env.DOH_SERVER_ECS_USE_PRECISE_IP` | Use the full client IP for EDNS Client Subnet | false |
| **service** | | |
| `service.type` | The service type | ClusterIP |
| `service.port` | The service port | 80 |
| `service.annotations` | Service annotations | |
| **ingress** | | |
| `ingress.enabled` | Disable (false) or enable (true) the ingress | false |
| `ingress.className` | The ingress class | nginx |
| `ingress.domainName` | The domain name that should be used to expose the ingress | doh.your-domain.com |
| `ingress.annotations` | Ingress annotations | |
| `ingress.nginxAnnotations` | Nginx specific annotations, only applied when `ingress.className` is `nginx` | |
| `ingress.pathType` | The ingress path type | Prefix |
| **probes** | | |
| `probesQuery` | The query used by the liveness and readiness probes | name=google.com&type=A |
| `probesPath` | The path used by the liveness and readiness probes. Defaults to `env.DOH_HTTP_PREFIX` when empty | |
| **image** | | |
| `image.repository` | The image repository | satishweb/doh-server |
| `image.tag` | The image tag | latest |
| `image.pullPolicy` | The image pull policy | IfNotPresent |

### Install the chart

Example install of the doh-server helm chart with a release name `my-release`:

```bash
helm install my-release \
  --set env.UPSTREAM_DNS_SERVER="udp:8.8.8.4:53" \
  --set ingress.enabled=true \
  --set ingress.domainName=doh.my-domain.com \
  ./doh-server-2.3.10.tgz
```

Or straight from the chart directory:

```bash
helm install my-release ./doh-server
```

## Uninstallation

To uninstall/delete the `my-release` deployment:

```bash
helm delete my-release
```
