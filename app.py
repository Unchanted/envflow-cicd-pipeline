import os
import uuid
from datetime import datetime, timezone

from flask import Flask, jsonify, redirect, render_template, request, url_for

MAX_TASK_LENGTH = 120

ENV_STYLES = {
    "development": {"label": "Development", "color": "#2563eb"},
    "staging": {"label": "Staging", "color": "#d97706"},
    "production": {"label": "Production", "color": "#16a34a"},
}


def create_app():
    app = Flask(__name__)
    app.config["APP_ENV"] = os.getenv("APP_ENV", "development")
    app.config["APP_VERSION"] = os.getenv("APP_VERSION", "local")
    app.config["SECRET_KEY"] = os.getenv("APP_SECRET_KEY", "dev-only-key")
    app.config["STARTED_AT"] = datetime.now(timezone.utc)
    app.config["TASKS"] = []

    def env_style():
        return ENV_STYLES.get(app.config["APP_ENV"], {"label": app.config["APP_ENV"].title(), "color": "#6b7280"})

    @app.get("/")
    def index():
        return render_template(
            "index.html",
            env=env_style(),
            version=app.config["APP_VERSION"],
            tasks=app.config["TASKS"],
        )

    @app.post("/add")
    def add_task():
        text = (request.form.get("task") or "").strip()
        if text and len(text) <= MAX_TASK_LENGTH:
            app.config["TASKS"].insert(
                0,
                {
                    "id": uuid.uuid4().hex[:8],
                    "text": text,
                    "created": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
                },
            )
        return redirect(url_for("index"))

    @app.post("/delete/<task_id>")
    def delete_task(task_id):
        app.config["TASKS"][:] = [t for t in app.config["TASKS"] if t["id"] != task_id]
        return redirect(url_for("index"))

    @app.get("/health")
    def health():
        healthy = os.getenv("BREAK_HEALTH", "0") != "1"
        uptime = (datetime.now(timezone.utc) - app.config["STARTED_AT"]).total_seconds()
        body = {
            "status": "healthy" if healthy else "unhealthy",
            "environment": app.config["APP_ENV"],
            "version": app.config["APP_VERSION"],
            "uptime_seconds": round(uptime, 1),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        return jsonify(body), 200 if healthy else 503

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
