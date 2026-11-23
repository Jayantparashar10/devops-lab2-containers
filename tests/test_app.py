import pytest

import app as app_module


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(app_module, "REDIS_HOST", "")
    monkeypatch.setattr(app_module, "_memory_count", 0)
    app_module.app.config["TESTING"] = True
    with app_module.app.test_client() as test_client:
        yield test_client


def test_index_reports_version_and_hostname(client):
    body = client.get("/").get_json()
    assert body["version"] == app_module.APP_VERSION
    assert body["hostname"]
    assert body["backend"] == "memory"


def test_visits_increase_in_memory(client):
    assert client.get("/visits").get_json()["visits"] == 1
    assert client.get("/visits").get_json()["visits"] == 2


def test_health_without_redis(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["redis"] == "not-configured"


def test_visits_returns_503_when_redis_is_down(client, monkeypatch):
    monkeypatch.setattr(app_module, "REDIS_HOST", "redis-that-does-not-exist")
    monkeypatch.setattr(app_module, "_redis_client", None)
    response = client.get("/visits")
    assert response.status_code == 503
    assert "redis unavailable" in response.get_json()["error"]
