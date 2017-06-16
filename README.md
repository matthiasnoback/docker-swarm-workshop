# Docker Swarm workshop

## Required Docker software

Prepare for this workshop by following the [installation instructions](https://docs.docker.com/engine/installation/) for Docker Engine.

Make sure you can run the following commands, showing version numbers higher than or equal to the following:

```bash
$ docker --version
Docker version 17.03.0-ce, build 60ccb22

$ docker-compose --version
docker-compose version 1.11.2, build dfed245

$ docker-machine --version
docker-machine version 0.10.0, build 76ed2a6
```

## Docker Hub account

If you don't have an account on [hub.docker.com](https://hub.docker.com), create one. Then log in using the command:

```bash
docker login
```

**Make sure you export your Docker Hub username as an environment variable**:

```bash
export DOCKER_HUB_USERNAME="matthiasnoback"
```

You can add this to `~/.bash_profile` too if you like, to make this variable available every time you start a new Bash session.

## VirtualBox

Make sure you have [VirtualBox](https://www.virtualbox.org/) installed on your machine.
