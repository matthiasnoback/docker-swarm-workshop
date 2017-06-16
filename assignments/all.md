# Workshop assignments

## Create a local Swarm

Create a local Swarm by running `bin/setup-local-swarm.sh` (or running those commands manually).

There's no need to SSH into a node. You can interact with its docker daemon by simply point the client to a different node using `docker-machine env`:

```bash
eval $(docker-machine env manager1)
```

Now you can inspect the node:

```bash
docker node ls
docker node ps [node ID]
```
 
Turn one of the worker nodes into another manager for the purpose of resilience. Figure out [how many managers](https://docs.docker.com/engine/swarm/raft/) would be required for safely managing a cluster of 3 nodes.

Don't forget to point the focus back to localhost:

```bash
eval $(docker-machine env -u)
```

## Spin up the backend server

Take a look at `backend/Dockerfile` and `backend/web/index.php`.

First you need to build and push the container image for this very simple `backend` service. You can do so by running `bin/build-and-push.sh`. Take a look at what the script does; make sure you understand how it works.

Go to [hub.docker.com](https://hub.docker.com) and take a look at your dashboard. You should see the image for the backend service listed there.

Now that the image is (publicly) available on the Docker Hub image registry, you can deploy the backend service to our cluster:

```bash
eval $(docker-machine env manager1)

docker service create \
    --replicas 1 \
    --name backend \
    "${DOCKER_HUB_USERNAME}/docker-swarm-workshop-backend"
```

Now take a look at what's going on inside the manager. Try `docker service ls`. Also try `docker node ls`, then `docker node ps [node ID]` to list all the tasks running on a specific node. Where does the single instance of the `backend` service currently run?

You can find out more about the `backend` service by running:

```bash
# Inspect deployment configuration, etc.
docker service inspect --pretty backend

# Find out where the backend service is currently running
docker service ps backend
```

Finally, change focus to the node that's actually running the service now, for example if the service runs on `manager1`, then run:

```bash
eval $(docker-machine) manager1
```

Now you can use regular `docker` commands like `docker ps` to figure out which containers are running on this node. This allows you to retrieve any other information you're usually interested in when it comes to running containers, for example the ports they are listening on. Run:

```bash
docker ps
```

And you should see that the `backend` service is listening on port 80.

## Leverage the ingress routing mesh

If you want to expose services to clients outside the swarm, you need to create them with a *published port*. Since you've created the `backend` service without doing so, you first need to remove it, the create it again:

```bash
docker service rm backend

docker service create \
    --replicas 1 \
    --name backend \
    --publish 80:80 \
    "${DOCKER_HUB_USERNAME}/docker-swarm-workshop-backend:latest"
```

The port format is `<PUBLISHED-PORT>:<TARGET-PORT>`.

Afterwards, look up the IP of any of the machines you created:

```bash
docker-machine ls
```

Then open one of the IPs in your browser. You should see:

```
I am the backend server
```

Although the service has only one instance, each node runs its own load balancer which routes incoming requests to a node that does run the service.

## Scaling

To be able to deal with the enormous number of incoming requests, you'd like to scale the backend service:

```bash
docker service scale backend=2
```

You can have more replicas, but it doesn't make a lot of sense with this small number of nodes. Take a look at what happens:

```bash
docker service ps backend
```

Optionally add `watch -n 1` in front of this command, to refresh this output automatically:

```bash
watch -n 1 docker service ps backend
```

It may take some time before the service will be replicated.

Eventually, you should see a list of two backend services with the status "Running".

## Updates

Right now, you don't know which node is processing which request.

Make a change to `backend/web/index.php` to add some information about the server, e.g. by adding these lines:

```php
print_r($_SERVER);
print_r($_ENV);
```

Build and push the image again:

```bash
bin/build-and-push.sh
```

Afterwards, update the service to the latest image by running:

```bash
docker service update backend \
    --image "${DOCKER_HUB_USERNAME}/docker-swarm-workshop-backend:latest"
```

Now, refresh the page in your browser and find out a way to identify which server is responding. 

These identifiers will be random strings. Now, figure out on which node the `backend` service is currently running. Switch to that node using `docker-machine env` and then use `docker ps` to find out the ID of the `backend` container on that node. Finally, run `docker inspect [container ID]`. You should find the identifier of the server under the expected key in the output of this command.

Now update the code to only print the identifier, instead of all the `$_SERVER` and `$_ENV` variables:

```php
// ...

echo "The responding server is: " . /* ... */;
```

Build and push the new version of this image using the `bin/build-and-push.sh` script, but **don't manually update the service yet. Instead, continue with the next assignment on "rolling updates".**

## Rolling updates

When you update the image for a service, you'll encounter some downtime. This doesn't make for a nice user experience. What you'd want is to recreate services one by one, with a little time in between. You can do this by providing the `--update-delay` option as well as an `--update-parallelism` option, like this:

```bash
docker service update backend \
    --image "${DOCKER_HUB_USERNAME}/docker-swarm-workshop-backend:latest" \
    --update-delay 20s \
    --update-parallelism 1
```

This will update the service tasks one by one, waiting 20 seconds in between updates. If you'd like to watch the progress, immediately run `watch -n 1 docker service ps backend` again.

## Health checks

To improve the update process and only mark a deployed service as "Running", you could add a command to its `Dockerfile` that could serve as a representative health check. In the case of the `backend` service it would be sufficient if it simply returns an HTTP response, something that could be checked with a simple `curl` call. 

Add the following lines to `backend/Dockerfile`:
   
```docker
HEALTHCHECK --interval=10s --timeout=3s \
    CMD curl -f http://localhost/healthcheck || exit 1
```

`exit 1` means: this container isn't healthy (yet or anymore).

Now, build and push the image again. Finally, run the update command again:

```bash
docker service update backend \
    --image "${DOCKER_HUB_USERNAME}/docker-swarm-workshop-backend:latest"
```

Wait for the service to be updated. Then see how Docker makes regular `/healthcheck` calls by figuring out where a service runs, which container ID belongs to it, then running `docker logs -f [container ID]`.

## Defining a stack in a Docker Compose file

The same transition we made from `docker` commands to a Docker Compose configuration file can be made here as well. Any number of services we'd like to use can be defined as a "stack" in a `docker-compose.yml` file. First remove the `backend` service from the Swarm:

```bash
docker service rm backend
```

Now create a `docker-compose.yml` file containing the following service definition:

```yaml
version: '3'

services:
    backend:
        image: "${DOCKER_HUB_USERNAME}/docker-swarm-workshop-backend:latest"
        ports:
            - "80:80"
```

Use the [Compose file reference](https://docs.docker.com/compose/compose-file/) to configure the deployment settings we've used above (rolling update and replica configuration). By the way, the Docker Compose configuration file really is a hybrid format, where some options may only apply to usage with Docker Compose, or Swarm, or both.

Finally, connect to a manager node (any node in our case), and run:

```bash
docker stack deploy \
    --compose-file ./docker-compose.yml \
    docker_swarm_workshop
```

You can use `docker stack ls`, `ps`, etc. to find out more about the stack you just deployed. Also, all of the previously discussed commands can still be used, like `docker service ps`, etc. However, the names of the services are now being automatically prefixed by the name of the stack, e.g. `docker_swarm_workshop_[service_name]`.

## Labels

First, add a Redis server to your `docker-compose.yml` file. Make it a single instance. The image used should be the [official `redis` image](https://hub.docker.com/_/redis/).

Now, Redis requires data storage on the node where it's running. Not every node might be suitable for that. They need to have a regular backup mechanism configured, and they may have stricter maintenance requirements. Let's label `worker1` as a special node, dedicated to services which have persistent data:

```bash
docker node update --label-add data=persistent worker1
```

Figure out using the [Compose file reference](https://docs.docker.com/compose/compose-file/#placement) how you can instruct the Swarm manager to place the `redis` service instance only on specific nodes. 

```bash
docker stack deploy \
    --compose-file ./docker-compose.yml \
    docker_swarm_workshop
```

Run:

```bash
docker stack ps docker_swarm_workshop
```

Verify that `redis` is indeed running on `worker1`.

> ### Bonus assignment
> 
> Set up a volume that can be used by Redis to store its data.

## Secrets

TODO Maybe connect to Redis using a password shared as a secret?
