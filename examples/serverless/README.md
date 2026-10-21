# Serverless deployment

The DNS over HTTP server runs as a container, so it can be deployed to a
serverless platform that supports custom containers.

## Alibaba Cloud Function Compute

`alibaba-fc-s.yaml` is a [Serverless Devs](https://www.serverless-devs.com/)
template for the Function Compute custom container runtime.

```bash
# The image has to be in a registry that the function can pull from.
s deploy -t ./alibaba-fc-s.yaml
```

The template deploys the image from the Docker Hub, change the
`customContainerConfig.image` to a registry of your own if that is
preferable.

The function serves the endpoint on the path that is set with
`DOH_HTTP_PREFIX` and listens on the port that is set with
`DOH_SERVER_LISTEN`, the port has to match the `caPort` of the function.

A serverless platform terminates the TLS itself, so the server should run
without a certificate and the platform has to be configured for HTTPS.
