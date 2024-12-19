IMAGE=satishweb/doh-server
IMAGE_TEST=satishweb/doh-server-test
ALPINE_PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/ppc64le,linux/s390x,linux/386
UBUNTU_PLATFORMS=linux/amd64,linux/arm/v7
DOCKER_BUILDX_CMD?=docker buildx

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
	EXTRA_BUILD_PARAMS += --push-git-tags
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
      --docker-buildx-cmd "${DOCKER_BUILDX_CMD}" \
	  ${EXTRA_BUILD_PARAMS}

build-ubuntu:
	$(L)./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${UBUNTU_PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${TAGNAME}-ubuntu" \
	  --docker-file "Dockerfile.ubuntu" \
      --docker-buildx-cmd "${DOCKER_BUILDX_CMD}" \
	  $$(echo ${EXTRA_BUILD_PARAMS}|sed 's/--mark-latest//')

test:
	$(L)docker build -t ${IMAGE_TEST}:${TAGNAME} -f ./Dockerfile.${OSF} .
	$(L)${MAKE} run-tests

test-all:
	$(L)${MAKE} all PUSH_IMAGES=true
	$(L)${MAKE} run-tests IMAGE=${IMAGE_TEST} TAGNAME=${TAGNAME}

run-tests:
	$(L)cd tests; pipenv install --python 3.12
	$(L)cd tests; pipenv run python ./test-doh-server.py --image ${IMAGE}:${TAGNAME}-alpine

# Commands:
#   make test OSF=alpine # Build local platform image and then run tests for alpine dockerfile
#   make test OSF=ubuntu # Build local platform image and then run tests for ubuntu dockerfile
#   make all # Test all platforms docker container image build for alpine and ubuntu (no tests)
#   make test-all # Build, push images and then run tests
#   make all LATEST=true PUSH_IMAGES=true PUSH_GIT_TAGS=true # Build and push images with latest tag and push git tags
