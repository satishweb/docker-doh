# Makefile
IMAGE=satishweb/doh-server
ALPINE_PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6
UBUNTU_PLATFORMS=linux/amd64,linux/arm/v7
CI_INFRA_KUBE_NAMESPACE=prod-argo-server
WORKDIR=$(shell pwd)
TAGNAME?=$(shell curl -s https://api.github.com/repos/m13253/dns-over-https/tags|jq -r '.[0].name')
OSF?=alpine

# Set L to + for debug
L=@

UBUNTU_IMAGE=ubuntu:20.04
ALPINE_IMAGE=alpine:1.13

ifdef PUSH
	EXTRA_BUILD_PARAMS = --push-images --push-git-tags
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


ci-infra-apply:
	${L}kustomize build build/ | kubectl apply -f -
	${L}sleep 5
	@# Below patch is needed because we exhaust docker pull limits too fast
	${L}for i in $$(kubectl -n ${CI_INFRA_KUBE_NAMESPACE} get deployments -l 'owner-name in (docker-doh-event-source-github,docker-doh-sensor-github)' -o jsonpath='{.items[*].metadata.name}');\
		do \
			kubectl -n ${CI_INFRA_KUBE_NAMESPACE} patch deployment $$i -p '{"spec":{"template":{"spec":{"containers":[{ "name":"main", "imagePullPolicy":"IfNotPresent"}]}}}}' ;\
		done

ci-infra-delete:
	${L}kustomize build build/workflow-templates | kubectl delete -f -
	${L}kustomize build build/ci | kubectl delete -f -

ci-infra-build:
	${L}kustomize build build/

ci-infra-diff:
	${L}kustomize build build/ | kubectl diff -f -
