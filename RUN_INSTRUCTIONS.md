## Running the project (developer checklist)

This file explains the common developer workflows for the HomeGenie project: running the services with Docker Compose, running a development server, running tests locally, and common troubleshooting steps (especially for Windows/Python devs).

### Prerequisites

- Docker Desktop (running)
- docker-compose (bundled with Docker Desktop)
- Python 3.11/3.12 (local venv for running tests or scripts)
- (Windows) PowerShell / cmd.exe as appropriate

If you're on Windows and plan to install DB drivers locally, prefer `psycopg[binary]` to avoid having to compile `asyncpg` with MSVC.

---

## Start the full stack (recommended for integration testing)

From the repository root (example path: `d:\Homegenie`):

```cmd
docker-compose -f d:\Homegenie\docker-compose.yml up -d --build
```

This will bring up the following services:
- `globalone` — Postgres (db)
- `homegenie-app` — API, nginx, simulator (unified container)
- `homegenie-mqtt` — Mosquitto broker

Verify containers are healthy:

```cmd
docker-compose -f d:\Homegenie\docker-compose.yml ps
```

Check app logs (supervisor-managed logs):

```cmd
docker logs --tail 200 homegenie-app
docker exec -it homegenie-app sh -c "cat /var/log/supervisor/api.log || echo 'no api.log'"
```

Health endpoints:

```cmd
curl http://localhost:8000/health
```

Notes:
- The container includes a frontend served by nginx on port `3000` and the API on `8000` (mapped to host ports). If nginx fails to start, check `docker/frontend/nginx.conf` or the supervisor logs.

---

## Run a local development backend (fast reload)

There is a development service `homegenie-dev` available in `docker-compose.yml` that runs the API with `uvicorn --reload` and mounts the local `src/` code for live editing.

Start only the dev backend (and any dependent services):

```cmd
docker-compose -f d:\Homegenie\docker-compose.yml up -d globalone homegenie-mqtt homegenie-dev
```

﻿# HomeGenie — Run Instructions (developer)

This file gives concise, step-by-step instructions to run HomeGenie locally for development and testing. The examples use Windows `cmd.exe` (adjust to PowerShell or bash as needed).

## Prerequisites
- Docker Desktop (with docker-compose)
- Python 3.11+ (use a venv for running tests and scripts)
- (Optional) Flutter SDK if working on the frontend

Repository root (examples): `D:\Homegenie`

## 1) Start full stack (Docker Compose)
From repo root:

```cmd
docker-compose -f D:\Homegenie\docker-compose.yml up -d --build
```

Services started include:
- `homegenie-mqtt` — Mosquitto MQTT broker
- `globalone` — Postgres DB (used for integration/PoC)
- `homegenie-app` / `homegenie-dev` — API + simulator (unified or dev image)

Check status/logs:

```cmd
docker-compose -f D:\Homegenie\docker-compose.yml ps
docker-compose -f D:\Homegenie\docker-compose.yml logs --tail=200 homegenie-app
```

API health (container exposes FastAPI on port 8000 by default; some compose mappings expose to host 8000/8080):

```cmd
curl http://localhost:8000/health
```

## 2) Run backend locally (no Docker) — quick dev loop

Use the provided venv (recommended) or create a new one.

Activate provided venv (Windows cmd):

```cmd
D:\Homegenie\env\Scripts\activate.bat
```

Or create a fresh venv:

```cmd
python -m venv .venv
.venv\Scripts\activate.bat
pip install -r config/requirements.txt
```

Run the API (from repo root) for local dev:

```cmd
uvicorn src.api.api_server:app --reload --port 8000
```

If you want the API to connect to a local MQTT broker, set these env vars (cmd):

```cmd
set HOMEGENIE_MQTT_HOST=localhost
set HOMEGENIE_MQTT_PORT=1883
```

## 3) Run tests (focused / full)

Activate the venv (see above) and run pytest. For a quick focused run (scheduler + DB tests):

```cmd
D:\Homegenie\env\Scripts\python.exe -m pytest -q tests/test_db_v2.py tests/test_schedules_api.py tests/test_scheduler_execution.py
```

To run the full test suite:

```cmd
pytest -q
```

Notes:
- Some integration tests require a Postgres DB and/or a live MQTT broker. Those tests are marked and can be skipped by default. To enable integration tests, set environment variables like `POSTGRES_URL` and `RUN_INTEGRATION=1` and run pytest with `-m integration` or `-k integration` as configured.
- On Windows, prefer `psycopg[binary]` if `asyncpg` wheels are not available.

## 4) Database migrations (Alembic)

The repo includes Alembic revisions for the DB PoC (SQLModel). To run migrations against a DB, set `POSTGRES_URL` and run:

```cmd
set POSTGRES_URL=postgresql+psycopg://homegenie:changeme@localhost:5432/homegenie_db
alembic upgrade head
```

Alembic config uses `src/core/db_v2`/SQLModel models. If you run migrations inside Docker, ensure `POSTGRES_URL` matches the container networking.

## 5) Device simulator & MQTT

The device simulator publishes simulated device state to MQTT topics (topics under `home/...`). To run it locally without Docker, ensure a broker is available at `HOMEGENIE_MQTT_HOST`/`HOMEGENIE_MQTT_PORT`. Example (start Mosquitto via Docker):

```cmd
docker run -d --name homegenie-mosquitto -p 1883:1883 eclipse-mosquitto:2
```

Then run the simulator (from repo root):

```cmd
python -m src.simulators.device_simulator
```

Note: The executor publishes commands to `home/{device_type}/{location}/command`; the simulator subscribes to matching topics.

## 6) Postgres PoC / snapshots

- The DB PoC is feature-gated behind settings in `src.core.settings_v2` (e.g., `POSTGRES_URL` and `ENABLE_POSTGRES_MIGRATION`).
- To enable periodic ContextStore snapshots, set `ENABLE_POSTGRES_MIGRATION=true` and configure `POSTGRES_URL` and `SNAPSHOT_INTERVAL_SECONDS` in settings or environment.

Example (cmd):

```cmd
set POSTGRES_URL=postgresql+psycopg://homegenie:changeme@localhost:5432/homegenie_db
set ENABLE_POSTGRES_MIGRATION=1
set SNAPSHOT_INTERVAL_SECONDS=300
```

Then start the API so the snapshot loop runs as part of the FastAPI lifespan.

## 7) Useful commands & troubleshooting

Show all containers:

```cmd
docker-compose -f D:\Homegenie\docker-compose.yml ps
```

Show logs for API container:

```cmd
docker-compose -f D:\Homegenie\docker-compose.yml logs --tail=200 homegenie-app
```

Open a shell inside the app container:

```cmd
docker exec -it homegenie-app cmd
```

If the API fails to start or endpoints return errors, check `docker-compose logs` and the app-level logs under `/var/log/supervisor` inside the container.

## 8) Next steps & automation (suggested)

- If you prefer, I can add `scripts/dev_start.bat` and `scripts/dev_start.ps1` to wrap the common docker-compose and env var setup for Windows. Tell me which shell you prefer and I will add them.
- If you want integration test helpers (start a temporary Mosquitto and Postgres for tests), I can add scripts and pytest fixtures to orchestrate them.

---

If you'd like a shorter or more detailed variant (for CI, for Docker-only runs, or for Windows PowerShell), tell me which target and I'll produce that version and optionally add helper scripts.
