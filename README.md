# DevOps Lab 2: Containers and Kubernetes

A small Flask visit counter used to show Docker images, containers, storage,
networking, Docker Compose, Kubernetes deployments, rolling updates, scaling
and continuous deployment with Jenkins.

## The app

| Route     | Response                                                        |
|-----------|-----------------------------------------------------------------|
| `/`       | Message, version, hostname (container or pod name), backend     |
| `/visits` | Adds 1 to the counter. Uses Redis if `REDIS_HOST` is set, else memory |
| `/health` | `{"status": "ok", ...}`, used by Docker and Kubernetes probes   |

The hostname in each response shows which container or pod answered. That
makes scaling and load balancing easy to see.

## Files

```
app.py, requirements*.txt, tests/   Flask app and unit tests
Dockerfile                          multi-stage: base -> test (runs pytest) -> runtime
docker-compose.yml                  web + Redis with a named volume and a private network
scripts/demo-storage.sh             Q3: writable layer vs named volume vs bind mount
scripts/demo-network.sh             Q4: container-to-container by name and by IP
k8s/configmap.yaml                  app settings as environment variables
k8s/deployment.yaml                 3 replicas, RollingUpdate (maxSurge 1, maxUnavailable 0), probes
k8s/service.yaml                    NodePort 30090
k8s/optional/hpa.yaml               autoscaling 2-6 pods on CPU (needs metrics-server)
Jenkinsfile                         CD: test -> build -> push to Docker Hub -> kubectl apply -> verify
```

## Quick start

```bash
docker build -t counter-app:1.0 .
docker run -d --name counter -p 8000:8000 counter-app:1.0
curl http://localhost:8000/

docker compose up -d --build        # web + Redis
curl http://localhost:8000/visits

minikube image load counter-app:1.0
kubectl apply -f k8s/
curl http://$(minikube ip):30090/
```
