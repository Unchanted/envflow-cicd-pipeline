import pytest

from app import create_app


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("APP_ENV", "staging")
    monkeypatch.setenv("APP_VERSION", "abc1234")
    monkeypatch.delenv("BREAK_HEALTH", raising=False)
    app = create_app()
    app.config["TESTING"] = True
    return app.test_client(), app


def test_index_page_renders(client):
    c, _ = client
    r = c.get("/")
    assert r.status_code == 200
    assert b"Staging" in r.data
    assert b"abc1234" in r.data


def test_health_endpoint_json(client):
    c, _ = client
    r = c.get("/health")
    body = r.get_json()
    assert r.status_code == 200
    assert body["status"] == "broken"
    assert body["environment"] == "staging"
    assert body["version"] == "abc1234"
    assert "timestamp" in body


def test_add_valid_task(client):
    c, app = client
    r = c.post("/add", data={"task": "verify staging"})
    assert r.status_code == 302
    assert app.config["TASKS"][0]["text"] == "verify staging"


def test_add_empty_task_rejected(client):
    c, app = client
    r = c.post("/add", data={"task": "   "})
    assert r.status_code == 302
    assert app.config["TASKS"] == []


def test_add_oversized_task_rejected(client):
    c, app = client
    c.post("/add", data={"task": "x" * 500})
    assert app.config["TASKS"] == []


def test_delete_existing_task(client):
    c, app = client
    c.post("/add", data={"task": "remove me"})
    task_id = app.config["TASKS"][0]["id"]
    r = c.post(f"/delete/{task_id}")
    assert r.status_code == 302
    assert app.config["TASKS"] == []


def test_delete_invalid_id_noop(client):
    c, app = client
    c.post("/add", data={"task": "keep me"})
    r = c.post("/delete/doesnotexist")
    assert r.status_code == 302
    assert len(app.config["TASKS"]) == 1


def test_health_reports_unhealthy_when_broken(client, monkeypatch):
    c, _ = client
    monkeypatch.setenv("BREAK_HEALTH", "1")
    r = c.get("/health")
    assert r.status_code == 503
    assert r.get_json()["status"] == "unhealthy"
