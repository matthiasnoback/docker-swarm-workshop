# Workshop assignments

## Create a local Swarm

Create a local Swarm by running `bin/setup-local-swarm.sh` (or run those commands manually).

*There's no need to SSH into a node.* You can interact with its Docker Engine by simply pointing your own Docker client to a different machine using `docker-machine env`:

```bash
eval $(docker-machine env manager1)
```

Now you can inspect the node:

```bash
# List the nodes in this cluster: 
docker node ls

# Inspect which tasks are running on a particular node: 
docker node ps [node ID]
```
 
[Promote one of the worker nodes to become a manager](https://docs.docker.com/engine/swarm/manage-nodes/#promote-or-demote-a-node) for the purpose of resilience. Figure out [how many managers](https://docs.docker.com/engine/swarm/raft/) would be required for safely managing a cluster of 3 nodes.

Don't forget to point the focus back to your local Docker Engine when you're done:

```bash
eval $(docker-machine env -u)
```

## Spin up the backend server

Take a look at `backend/Dockerfile` and `backend/web/index.php`.

First you need to build and push the container image for this very simple `backend` service. You can do so by running `bin/build-and-push.sh`. Take a look at what the script does; make sure you understand how it works.

Go to [hub.docker.com](https://hub.docker.com), sign in if necessary, and take a look at your dashboard. You should see the image for the backend service listed there.

Now that the image is (publicly) available on the Docker Hub image registry, you can deploy the backend service to the cluster:

```bash
eval $(docker-machine env manager1)

docker service create \
    --replicas 1 \
    --name backend \
    "${DOCKER_HUB_USERNAME}/docker-swarm-workshop-backend"
```

Now take a look at what's going on inside the manager:

```bash
# Which services are deployed to this Swarm?
docker service ls

# Inspect deployment configuration, etc.
docker service inspect --pretty backend
 
# Where is the backend service currently running?
docker service ps backend
```

Finally, change focus to the node that's actually running the service now, for example if the service runs on `manager1`, then run:

```bash
eval $(docker-machine env manager1)
```

Now you can use regular `docker` commands like `docker ps` to figure out which containers are running on this node. This allows you to retrieve any other information you're usually interested in when it comes to running containers, for example the ports they are listening on. Run:

```bash
# Find out which containers are running on this engine
docker ps

# Take a look at the logs of a specific container:
docker logs [container ID]

# Inspect the container configuration, etc.:
docker inspect [container ID]
```

## Leverage the ingress routing mesh

If you want to expose services to clients outside the swarm (like your browser), you need to create them with a *published port*. Since you've created the `backend` service without doing so, you first need to remove it, then create it again:

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

Or request the IP address of a specific node:

```bash
echo $(docker-machine ip manager1)
```

Then open one of the IPs in your browser. You should see:

```
I am the backend server
```

If you don't get this message, run `docker service ps backend`: it might state the the "Current state" is "Preparing". This usually means that Docker is still downloading the image for the container before it can start it. Just wait until it shows "Running" and then try again.

Although the `backend` service has only one instance, each node runs its own load balancer which routes incoming requests to a node that does run the service, that's why you can use any node's advertised IP address.

## Scaling

To be able to deal with the *enormous* number of incoming requests, you'd like to scale the backend service:

```bash
docker service scale backend=3
```

You can have more replicas, but it doesn't make a lot of sense with this small number of nodes. Take a look at what happens:

```bash
docker service ps backend
```

Optionally add `watch -n 1` in front of this command, to refresh this output automatically:

```bash
watch -n 1 docker service ps backend
```

It may take some time before the service will be replicated. If you run `docker service ls` and check the value under "Replicas", this may still be "2/3", but it will eventually be "3/3".

## Updates

Right now, you don't know which node is processing which request, simply by looking at the web page it shows (nor any of its response headers).

Make a change to `backend/web/index.php` to add some behind-the-scenes information about the server, e.g. by adding these lines:

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

These identifiers will be random strings. Now, figure out on which node the `backend` service is currently running. Switch to that node using `docker-machine env` and then use `docker ps` to find out the ID of the `backend` container on that node. Finally, run `docker inspect [container ID]`. You should find the identifier of the server somewhere in the output of this command.

Update the code to only print this identifier, instead of all the `$_SERVER` and `$_ENV` variables:

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
    --update-delay 15s \
    --update-parallelism 1
```

This will update the service tasks one by one, waiting 15 seconds in between updates. If you'd like to watch the progress, immediately run `watch -n 1 docker service ps backend` again.

## Health checks

To improve the update process and only mark a deployed service as "Running", you could add a command to its `Dockerfile` that could serve as a representative health check. In the case of the `backend` service it would be sufficient if it simply returns an HTTP response, something that could be checked with a simple `curl` call. 

Add the following lines to `backend/Dockerfile`:
   
```docker
HEALTHCHECK --interval=10s --timeout=3s \
    CMD curl -f http://localhost/healthcheck || exit 1
```

`exit 1` means: "this container isn't healthy" (yet or anymore).

Now, build and push the image again. Finally, run the update command again:

```bash
docker service update backend \
    --image "${DOCKER_HUB_USERNAME}/docker-swarm-workshop-backend:latest"
```

Wait for the service to be updated. Then figure out on which node a service runs, which container ID it correponds with, and finally run `docker logs -f [container ID]`. You should see how Docker makes regular `/healthcheck` calls.

## Defining a stack in a Docker Compose file

You probably already know that you can use separate `docker` commands, or work with a Docker Compose configuration file. The same is true for Swarm. Any number of services you'd like to deploy can together be defined as a "stack" inside a `docker-compose.yml` file.

First, remove the `backend` service from the Swarm:

```bash
docker service rm backend
```

Now create a `docker-compose.yml` file containing the following service definition:

```yaml
# we need version 3.1 because we're going to work with Secrets later on...
version: '3.1'

services:
    backend:
        image: "${DOCKER_HUB_USERNAME}/docker-swarm-workshop-backend:latest"
        ports:
            - "80:80"
```

Use the [Compose file reference](https://docs.docker.com/compose/compose-file/) to figure out how to define the same deployment settings you've used above (rolling update and replica configuration). By the way, the Docker Compose configuration file really is a hybrid format, where some options may only apply to usage with Docker Compose, or Swarm, or both.

Finally, connect to a manager node (any node in our case), and run:

```bash
docker stack deploy \
    --compose-file ./docker-compose.yml \
    workshop
```

You can use `docker stack ls`, `ps`, etc. to find out more about the stack you just deployed. Also, all of the previously discussed commands can still be used, like `docker service ps`, etc. However, the names of the services are now being automatically prefixed by the name of the stack, e.g. `workshop_[service_name]`.

## Labels

Add a Redis server to your `docker-compose.yml` file. Make it a single instance. The image used should be the [official `redis` image](https://hub.docker.com/_/redis/). Use the `alpine` tag: `redis:alpine`.

Now, Redis requires data storage on the node where it's running. Not every node might be suitable for that. They need to have a regular backup mechanism configured, and they may have stricter maintenance requirements. Let's label `worker1` as such a special node, dedicated to services which have persistent data:

```bash
docker node update --label-add data=persistent worker1
```

Figure out using the [Compose file reference](https://docs.docker.com/compose/compose-file/#placement) how you can instruct the Swarm manager to place the `redis` service instance only on nodes with specific labels. Then redeploy the stack:

```bash
docker stack deploy \
    --compose-file ./docker-compose.yml \
    workshop
```

Afterwards, run:

```bash
docker stack ps workshop
```

Verify that `redis` is indeed running on `worker1`.

> ### Tip: create a deploy script
>
> It may be smart to combine the commands you need to run to redeploy your stack and follow along with the status of the deployment process into a convenient script in `bin/`. Take a look at the scripts in that directory for some inspiration.

## Connect to Redis

Now that you have a running Redis instance, you can connect to it from the `backend` service. Just add the following lines to the end of the `index.php` script:

```php
$redis = new Redis();
$redis->connect('redis');
echo 'Number of visits: ' . $redis->incr('visitors') . "\n";
```

Now build, push and redeploy.

Visit the website and you should see the visits counter increment every time you refresh the page.

## Global mode

Swarm managers distribute replicated services across nodes in the cluster. However, in some cases you simply want to make sure that each node has one instance of a service running. For example, you may need a monitoring agent to be active on each node. This is called ["global mode"](https://docs.docker.com/engine/swarm/how-swarm-mode-works/services/#replicated-and-global-services). You can run a service defined in `docker-compose.yml` as a global service by adding [`mode: global`](https://docs.docker.com/compose/compose-file/#mode) to the `deploy` section of the service's definition.

Now, add a global monitoring service ([Google's cadvisor](https://hub.docker.com/r/google/cadvisor/)) to the stack: 

```yaml
    cadvisor:
        image: google/cadvisor
        hostname: '{{.Node.ID}}'
        command: -logtostderr -docker_only
        volumes:
            - /:/rootfs:ro
            - /var/run:/var/run:rw
            - /sys:/sys:ro
            - /var/lib/docker/:/var/lib/docker:ro
        deploy:
            mode: global
        ports:
            # Don't expose cadvisor in a production environment!
            - 8080:8080
```

Deploy the stack again and you should be able to take a look at `cadvisor`'s monitoring website by visiting `[IP of any node]:8080`.

Unfortunately, Docker's own built-in load balancing works against us here. We get redirected to different nodes all the time. One way to fix (temporarily) fix this is to limit deployment of `cadvisor` to one node, e.g. `worker1`. Doing so will at least allow you to click around. 

The main screen gives an overview of resource usage by the node itself. Clicking on "Docker Containers" will allow you to inspect resource usage per container.

You can generate some load by manually refreshing the `backend` website, or for example by running Apache Bench:

```bash
ab -n 500 http://$(docker-machine ip manager1)/
```

> ### Bonus
>
> If you'd like to have a nice monitoring dashboard for the nodes in the cluster, try out this tutorial: [Monitoring Docker Swarm with cAdvisor, InfluxDB and Grafana](https://botleg.com/stories/monitoring-docker-swarm-with-cadvisor-influxdb-and-grafana/)

Another type of container that can be useful is a so-called utility container. A utility container is just a simple container (`alpine` often suffices). You deploy it globally (but only when you need to, if you're not using it, simply remove it from the Swarm). When it is running inside the Swarm, you can test Swarm features, like networking, or the secrets functionality which we'll cover in the next assignment.

To set up such a utility container, add the following to `docker-compose.yml`.

```yaml
utility:
    image: alpine
    # Force the container to keep running for a long time
    command: sleep 10000000
```

Then redeploy.

Now put your focus on a specific node, e.g. `manager1`: 

```bash
eval $(docker-machine env manager1)
```

Then run `docker ps` to find out the container ID for the utility container. Finally, "exec" into the utility container to open an interactive shell prompt inside of it:

```bash
docker exec -it [container ID] sh
```

You should see `/ # ` and a cursor. Take a look around (there's not really much to see). Try running:

```bash
apk update && apk add drill
```

This will install `drill`, which you can use to inspect DNS information, for example, try:

```bash
drill redis
```

Of course you can install any other tool you like, or use a different base image.

## Secrets

A [secret](https://docs.docker.com/engine/swarm/secrets/#simple-example-get-started-with-secrets) is data that can be shared amongst services. It will be encrypted and stored by the Swarm managers. You can manually add a secret to a Swarm, by running:

```
docker secret create [name_of_secret] [contents_of_secret]
```

If you do it manually, add the following to your [`docker-compose.yml` file](https://docs.docker.com/compose/compose-file/#secrets):

```yaml
secets:
    name_of_secret:
        external: true
```

You can also put a secret in a file and load it in `docker-compose.yml` as follows:
 

```yaml
secets:
    name_of_secret:
        file: [path to file]
```

Services need to have explicitly given access to these secrets. 

Define a secret called `db_password`, make it point to the already existing file `./db_password.txt`. Then give the utility container access to it:

```yaml
services:
    utility:
        secrets:
            - db_password
```

Redeploy the stack, then log in to the utility container and run:

```bash
cat /run/secrets/db_password
```

This should show you the secret password, since secrets will be shared with services by *mounting* them under `/run/secrets`.

Now it would be really cool if we could make Redis use this password, forcing clients to log in first before being able to run queries. The normal way to set a password for Redis would be to override the command for the service:

```yaml
service:
    redis:
        # ...
        command: redis-server --requirepass koekje
```

However, you want the password to be read from the `db_password` file instead of hard-coding it. It took me some time to [figure it out](https://php-and-symfony.matthiasnoback.nl/2017/06/making-a-docker-image-ready-for-swarm-secrets/) but this is a pretty clean way to do it:

```yaml
service:
    redis:
        # ...
        command:
            - "sh"
            - "-c" 
            - "redis-server --requirepass \"$$(cat /run/secrets/db_password)\""
```

Don't forget to actually make the secret available to the `redis` service (you already did the same thing for the `utility` service).

After making these changes to your `docker-compose.yml` file, redeploy again.

Visiting the backend service in the browser should show you an authentication error. After all, you've set the password on the server, but you don't use it in the client yet. To do so, add the following line, directly after the line that connects to Redis:

```php
$redis->auth(file_get_contents('/run/secrets/db_password'));
```

You should also make the `db_password` available to the `backend` service for this work.

Now you will have to rebuild the service image and redeploy the stack. After some time, everything should be okay and the visits counter should be working again.

> If you don't visit the website for a while, the visits counter will be a lot higher than the last time you refreshed the page. How do you explain this? Could you think of a way to fix this? Just make it work!

## Networks

Not every service needs to be able to communicate with every other service inside a cluster. It's smart to limit access to services.

First, consider which services need to publish their ports to the internet, and which services only need to be reachable by other services in the cluster. These "internal" services shouldn't have any published ports; the ports they expose (as defined using the `EXPOSE` keyword in their respective `Dockerfile`s) can already be reached by services in the Swarm. Finally, group services according to reachability and define [separate *networks*](https://docs.docker.com/engine/swarm/networking/) for them. This effectively blocks communication where it isn't allowed or expected.

In our example: `backend` should be able to talk to `redis`. `utility` and `cadvisor` should not be exposed to the internet.

In your configuration file you can [define networks](https://docs.docker.com/compose/compose-file/#network-configuration-reference) as follows:

```yaml
networks:
    name_of_network:
        driver: overlay
```

To connect a service to a network:

```yaml
services:
    name_of_service:
        networks:
            - name_of_network
```

Define some networks that make sense based on the advice above. Redeploy and make sure everything still works. To verify that, for example, `cadvisor` isn't available to the `backend` service, you could "exec" into the `backend` service and try to ping `cadvisor`. Or you could connect the `utility` service to the same networks as `backend` is connected to, then "exec" into the `utility` service and do the same thing.

## Bonus: Set up a storage volume for Redis 

Set up a volume that can be used by Redis to store its data (so that it can be backed up by a fictitious cron job or dedicated backup container running on `worker1`).

## Bonus: Try Prometheus for collecting and monitoring relevant statistics

Read [this article](http://blog.alexellis.io/prometheus-monitoring/) then build a `/metrics` endpoint for the `backend` service. Add a `prometheus` service and make it read from the metrics point. You can use the [PHP client library](https://github.com/Jimdo/prometheus_client_php/) to start collecting metrics (for example the visits count).

## Removing everything

To shut down the cluster and save yourself some resources:

```bash
eval $(docker-machine env -u)
docker-machine rm manager1 worker1 worker2
```
