#!/usr/bin/env bash
# Q3 - Docker storage demo
#   Part A: data written in the container's writable layer is lost when the container is removed
#   Part B: data in a named volume survives container removal
#   Part C: a bind mount shares a host folder with the container, in both directions
# Usage: scripts/demo-storage.sh            run the demo
#        scripts/demo-storage.sh --cleanup  remove the volume and the bind folder
set -euo pipefail

IMG="${DEMO_IMAGE:-alpine:3.20}"
VOLUME="lab2-data"
BIND_DIR="$(pwd)/bind-data"

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

if [[ "${1:-}" == "--cleanup" ]]; then
    docker rm -f storage-demo-a storage-demo-b >/dev/null 2>&1 || true
    docker volume rm "$VOLUME" >/dev/null 2>&1 || true
    rm -rf "$BIND_DIR"
    echo "Cleaned up volume $VOLUME and folder $BIND_DIR"
    exit 0
fi

step "Part A: container writable layer (data is lost)"
run docker run --name storage-demo-a "$IMG" sh -c 'echo "written at $(date)" > /tmp/note.txt && cat /tmp/note.txt'
run docker rm storage-demo-a
run docker run --rm "$IMG" sh -c 'cat /tmp/note.txt 2>/dev/null || echo "RESULT: /tmp/note.txt does not exist in the new container"'

step "Part B: named volume (data survives)"
run docker volume create "$VOLUME"
run docker run --name storage-demo-b -v "$VOLUME":/data "$IMG" sh -c 'echo "saved in volume at $(date)" > /data/note.txt && cat /data/note.txt'
run docker rm storage-demo-b
run docker run --rm -v "$VOLUME":/data "$IMG" sh -c 'echo "RESULT: new container reads:"; cat /data/note.txt'
run docker volume inspect "$VOLUME" --format 'Volume {{.Name}} is stored on the host at {{.Mountpoint}}'

step "Part C: bind mount (host folder shared with the container)"
mkdir -p "$BIND_DIR"
run docker run --rm --user "$(id -u):$(id -g)" -v "$BIND_DIR":/data "$IMG" sh -c 'echo "written from inside the container" > /data/from-container.txt'
run ls -l "$BIND_DIR"
run cat "$BIND_DIR/from-container.txt"
echo "written on the host at $(date)" > "$BIND_DIR/from-host.txt"
printf '\n(created %s on the host)\n' "$BIND_DIR/from-host.txt"
run docker run --rm -v "$BIND_DIR":/data "$IMG" sh -c 'echo "RESULT: container reads the host file:"; cat /data/from-host.txt'

step "Summary"
echo "Writable layer : removed with the container"
echo "Named volume   : managed by Docker, kept until 'docker volume rm $VOLUME'"
echo "Bind mount     : a normal host folder ($BIND_DIR)"
