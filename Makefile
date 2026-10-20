IMAGE=satishweb/doh-server
IMAGE_TEST=satishweb/doh-server-test
ALPINE_PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/ppc64le,linux/s390x,linux/386
UBUNTU_PLATFORMS=linux/amd64,linux/arm/v7
DOCKER_BUILDX_CMD?=docker buildx

# Pinned upstream release that gets built into the image.
# https://github.com/m13253/dns-over-https/releases
# Override to build another version:  make all DOH_VERSION=v2.3.11
DOH_VERSION?=v2.3.10

WORKDIR=$(shell pwd)
# The image tag follows the upstream version, e.g. v2.3.10
TAGNAME?=$(DOH_VERSION)
OSF?=alpine
HELM_CHART_DIR=helm/doh-server
HELM_CHART_VERSION?=2.3.10

# Set L to + for debug
L=@

# Build arguments passed to the docker build
BUILD_ARGS=--build-arg DOH_VERSION=$(DOH_VERSION)

ifdef PUSH_IMAGES
	EXTRA_BUILD_PARAMS += --push-images
endif

ifdef PUSH_GIT_TAGS
	EXTRA_BUILD_PARAMS += --push-git-tags
endif

ifdef LATEST
	EXTRA_BUILD_PARAMS += --mark-latest
endif

ifdef NO_CACHE
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
	  $(BUILD_ARGS) \
	  ${EXTRA_BUILD_PARAMS}

build-ubuntu:
	$(L)./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${UBUNTU_PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${TAGNAME}-ubuntu" \
	  --docker-file "Dockerfile.ubuntu" \
      --docker-buildx-cmd "${DOCKER_BUILDX_CMD}" \
	  $(BUILD_ARGS) \
	  $(filter-out --mark-latest,${EXTRA_BUILD_PARAMS})

test:
	$(L)docker build -t ${IMAGE_TEST}:${TAGNAME}-$(OSF) -f ./Dockerfile.$(OSF) .
	$(L)${MAKE} run-tests

test-all:
	$(L)${MAKE} all PUSH_IMAGES=true
	$(L)${MAKE} run-tests

run-tests:
	$(L)cd tests; pipenv install --python 3.12
	$(L)cd tests; pipenv run python ./test-doh-server.py --image ${IMAGE_TEST}:${TAGNAME}-$(OSF)

helm-lint:
	$(L)helm lint ${HELM_CHART_DIR}

helm-package:
	$(L)cd helm && helm package --version ${HELM_CHART_VERSION} --app-version ${DOH_VERSION} --destination . ${HELM_CHART_DIR}

# Commands:
#   make test OSF=alpine # Build local platform image and then run tests for alpine dockerfile
#   make test OSF=ubuntu # Build local platform image and then run tests for ubuntu dockerfile
#   make all # Test all platforms docker container image build for alpine and ubuntu (no tests)
#   make test-all # Build, push images and then run tests
#   make all LATEST=true PUSH_IMAGES=true PUSH_GIT_TAGS=true # Build and push images with latest tag and push git tags
