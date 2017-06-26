#!/usr/bin/env bash

export PS4="\[\e[33m\]Running:\[\e[m\] "

set -eux

docker-machine create -d virtualbox manager1
docker-machine create -d virtualbox worker1
docker-machine create -d virtualbox worker2

# Let the Docker client talk to `manager1`
eval $(docker-machine env manager1)

# Get manager's IP
MANAGER_IP=$(docker-machine ip manager1)

# Initialize the Swarm with `manager1`'s IP as the advertised address
docker swarm init --advertise-addr "${MANAGER_IP}"

# Collect the join token for workers
WORKER_JOIN_TOKEN="$(docker swarm join-token -q worker)"

# Let the Docker client talk to `worker1`
eval $(docker-machine env worker1)

# Let `worker1` join the swarm
docker swarm join \
    --token "${WORKER_JOIN_TOKEN}" \
    --advertise-addr "$(docker-machine ip worker1)" \
    "${MANAGER_IP}":2377

# Let the Docker client talk to `worker2`
eval $(docker-machine env worker2)

# Let `worker2` join the swarm
docker swarm join \
    --token "${WORKER_JOIN_TOKEN}" \
    --advertise-addr "$(docker-machine ip worker2)" \
    "${MANAGER_IP}":2377
