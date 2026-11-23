#!/usr/bin/env bash
# Q4 - Docker network demo
#   Two containers (web app + Redis) on a user-defined bridge network talk to
#   each other by container name and by container IP address.
#   A container on the default bridge cannot resolve those names.
# Needs the image counter-app:1.0 from Q1.
# Usage: scripts/demo-network.sh            run the demo
#        scripts/demo-network.sh --cleanup  remove the containers and the network
set -euo pipefail

NET="lab2-net"
APP_IMAGE="${APP_IMAGE:-counter-app:1.0}"
REDIS_IMAGE="${REDIS_IMAGE:-redis:7-alpine}"
IMG="${DEMO_IMAGE:-alpine:3.20}"

step() { printf '\n========== %s ==========\n' "$*"; }
run()  {
    local shown="" a
    for a in "$@"; do
        if [[ "$a" == *[[:space:]\$\>\|\;\&\(\)]* ]]; then
            if [[ "$a" == *"'"* ]]; then shown+="\"$a\" "; else shown+="'$a' "; fi
        else
            shown+="$a "
        fi
    done
    printf '\n$ %s\n' "${shown% }"
    "$@"
}

cleanup() {
    docker rm -f lab2-web lab2-redis lab2-outsider >/dev/null 2>&1 || true
    docker network rm "$NET" >/dev/null 2>&1 || true
}

if [[ "${1:-}" == "--cleanup" ]]; then
    cleanup
    echo "Removed containers lab2-web, lab2-redis, lab2-outsider and network $NET"
    exit 0
fi
cleanup

step "Create a user-defined bridge network"
run docker network create --driver bridge "$NET"
run docker network ls --filter name="$NET"

step "Start Redis and the web app on the network"
run docker run -d --name lab2-redis --network "$NET" "$REDIS_IMAGE"
run docker run -d --name lab2-web --network "$NET" -e REDIS_HOST=lab2-redis -p 8000:8000 "$APP_IMAGE"
sleep 3

REDIS_IP=$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NET\").IPAddress}}" lab2-redis)
WEB_IP=$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NET\").IPAddress}}" lab2-web)
run docker network inspect "$NET" --format '{{range .Containers}}{{.Name}} -> {{.IPv4Address}}{{"\n"}}{{end}}'

step "Communication by container NAME (Docker DNS)"
run docker run --rm --network "$NET" "$IMG" ping -c 2 lab2-redis
run docker run --rm --network "$NET" "$IMG" wget -qO- http://lab2-web:8000/health
echo
echo "The web app reaches Redis by the name 'lab2-redis' (REDIS_HOST=lab2-redis):"
run curl -s http://localhost:8000/visits
run curl -s http://localhost:8000/visits

step "Communication by container IP ADDRESS"
echo "lab2-redis IP = $REDIS_IP    lab2-web IP = $WEB_IP"
run docker run --rm --network "$NET" "$IMG" ping -c 2 "$REDIS_IP"
run docker run --rm --network "$NET" "$IMG" wget -qO- "http://$WEB_IP:8000/health"

step "A container on the default bridge cannot use these names"
run docker run -d --name lab2-outsider "$IMG" sleep 300
run docker exec lab2-outsider sh -c "ping -c 1 -W 2 lab2-redis || echo 'RESULT: name lab2-redis not found from the default bridge'"

step "Done. Run 'scripts/demo-network.sh --cleanup' to remove everything."
