#!/usr/bin/env bash -eux

export PS4="\[\e[33m\]Running:\[\e[m\] "

eval $(docker-machine env -u)

BACKEND_SERVICE_TAG="${DOCKER_HUB_USERNAME}/docker-swarm-workshop-backend:latest"

docker build \
    -t "${BACKEND_SERVICE_TAG}" \
    -f backend/Dockerfile \
    backend/

docker push ${BACKEND_SERVICE_TAG}
