# docker-rpi-traefik

Traefik Docker image based on Alpine for the Raspberry Pi.

Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy.

### Develop and test builds

Just type:

```
./docker-build.sh
```

### Create final release and publish to Docker Hub

```
create-release.sh
```


### Run

Given the docker image with name `jriguera/traefik`:

```
docker run --name router -p 80:80 -v /var/run/docker.sock:/var/run/docker.sock -ti jriguera/traefik
```


# Author

Jose Riguera `<jriguera@gmail.com>`
