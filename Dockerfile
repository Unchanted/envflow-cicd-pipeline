FROM python:3.12-slim

ARG GIT_SHA=local

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${GIT_SHA}

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir Flask==3.0.3 gunicorn==22.0.0

COPY app.py .
COPY templates ./templates
COPY static ./static

RUN useradd --create-home envflow
USER envflow

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
