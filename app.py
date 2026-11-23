"""DevOps Lab 2 - visit counter web app.

Runs on its own (counts visits in memory) or with Redis (counts are shared
and survive app restarts). The response includes the hostname, so with
several containers or Kubernetes pods you can see which one answered.
"""
import os
import socket
import threading

import redis
from flask import Flask, jsonify

app = Flask(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
APP_MESSAGE = os.environ.get("APP_MESSAGE", "Hello from the Lab 2 counter app")
REDIS_HOST = os.environ.get("REDIS_HOST", "")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))

_memory_count = 0
_memory_lock = threading.Lock()
_redis_client = None


def backend_name() -> str:
    return "redis" if REDIS_HOST else "memory"


def get_redis():
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.Redis(
            host=REDIS_HOST, port=REDIS_PORT, socket_connect_timeout=2, socket_timeout=2
        )
    return _redis_client


def increment_visits() -> int:
    global _memory_count
    if REDIS_HOST:
        return int(get_redis().incr("visits"))
    with _memory_lock:
        _memory_count += 1
        return _memory_count


@app.route("/")
def index():
    return jsonify(
        message=APP_MESSAGE,
        version=APP_VERSION,
        hostname=socket.gethostname(),
        backend=backend_name(),
    )


@app.route("/visits")
def visits():
    try:
        count = increment_visits()
    except redis.RedisError as exc:
        return jsonify(error=f"redis unavailable: {exc}"), 503
    return jsonify(visits=count, backend=backend_name(), hostname=socket.gethostname())


@app.route("/health")
def health():
    redis_state = "not-configured"
    if REDIS_HOST:
        try:
            get_redis().ping()
            redis_state = "up"
        except redis.RedisError:
            redis_state = "down"
    return jsonify(status="ok", version=APP_VERSION, redis=redis_state)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
