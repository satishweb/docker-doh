# Author: Satish Gaikwad <satish@satishweb.com>
FROM golang:1.13-alpine AS doh-build
LABEL MAINTAINER satish@satishweb.com

RUN apk add --no-cache git make jq curl

WORKDIR /src

# Lets download latest version of DOH
RUN DOH_VERSION_LATEST="$(curl -s https://api.github.com/repos/m13253/dns-over-https/tags|jq -r '.[0].name')" \
    && wget "https://github.com/m13253/dns-over-https/archive/${DOH_VERSION_LATEST}.zip" -O doh.zip \
    && unzip doh.zip \
    && rm doh.zip \
    && cd dns-over-https* \
    && make doh-server/doh-server \
    && mkdir /dist \
    && cp doh-server/doh-server /dist/doh-server \
    && echo ${DOH_VERSION_LATEST} > /dist/doh-server.version

FROM alpine:3.9
LABEL MAINTAINER satish@satishweb.com

COPY --from=doh-build /dist /server
COPY doh-server.sample.conf /server/doh-server.sample.conf

# Install required packages by docker-entrypoint
RUN apk add --no-cache bash gettext

# Add docker entrypoint and make it executable
ADD docker-entrypoint /docker-entrypoint
RUN chmod u+x /docker-entrypoint

EXPOSE 8053

ENTRYPOINT ["/docker-entrypoint"]
CMD [ "/server/doh-server", "-conf", "/server/doh-server.conf" ]

# Healthcheck
HEALTHCHECK --interval=1m --timeout=30s --start-period=1m CMD wget "localhost:$(echo ${DOH_SERVER_LISTEN}|awk -F '[:]' '{print $2}')${DOH_HTTP_PREFIX}?name=google.com&type=A" -O /dev/null || exit 1
