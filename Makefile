IMAGE=satishweb/doh-server
ALPINE_PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/ppc64le,linux/s390x,linux/386
UBUNTU_PLATFORMS=linux/amd64,linux/arm/v7,linux/ppc64le,linux/s390x

WORKDIR=$(shell pwd)
TAGNAME?=$(shell curl -s https://api.github.com/repos/m13253/dns-over-https/tags|jq -r '.[0].name')
OSF?=alpine

# Set L to + for debug
L=@

UBUNTU_IMAGE=ubuntu:22.04
ALPINE_IMAGE=alpine:3.19

ifdef PUSH_IMAGES
	EXTRA_BUILD_PARAMS = --push-images
endif

ifdef PUSH_GIT_TAGS
	EXTRA_BUILD_PARAMS = --push-git-tags
endif


ifdef LATEST
	EXTRA_BUILD_PARAMS += --mark-latest
endif

ifdef NO-CACHE
	EXTRA_BUILD_PARAMS += --no-cache
endif

all: build-alpine build-ubuntu

build-alpine:
	$(L)./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${ALPINE_PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${TAGNAME}-alpine" \
	  --docker-file "Dockerfile.alpine" \
	  ${EXTRA_BUILD_PARAMS}

build-ubuntu:
	$(L)./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${UBUNTU_PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${TAGNAME}-ubuntu" \
	  --docker-file "Dockerfile.ubuntu" \
	  $$(echo ${EXTRA_BUILD_PARAMS}|sed 's/--mark-latest//')

test:
	$(L)docker build -t ${IMAGE}:${TAGNAME} -f ./Dockerfile.${OSF} .

# Commands:
#   make test OSF=apline # test alpine dockerfile
#   make test OSF=ubuntu # test ubuntu dockerfile
#   make all # Test all platforms on alpine and ubuntu
#   make all LATEST=true PUSH_IMAGES=true PUSH_GIT_TAGS=true # Build and push images with latest tag and push git tags
#   make all LATEST=true PUSH_IMAGES=true IMAGE=satishweb/doh-server-test # Build and push images with latest tag and push git tags to satishweb/doh-server-test
