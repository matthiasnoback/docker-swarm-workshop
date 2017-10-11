#!/usr/bin/env bash

set -eu

export PS4="\[\e[33m\]Running:\[\e[m\] "

eval $(docker-machine env manager1)
docker stack deploy -c docker-compose.yml workshop
watch -n 1 docker stack ps workshop
