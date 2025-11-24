# HomeGenie – Copilot Project Instructions

> You are assisting on **HomeGenie – Adaptive Smart Home Assistant for Personalized Living**.  
> This project is already architected and implemented.  
> Your primary job is to **respect the existing architecture and patterns**, not to redesign it.

---

## 1. Core Goal of the Project

HomeGenie is an **Agentic AI–based multi-agent smart home system** that:

- Uses **Planner, Sensor, Executor, Memory, and Scheduler agents** that collaborate via a shared context and MQTT.
- Controls **simulated and (future) real devices** via MQTT and Home Assistant / other IoT platforms.
- Learns user preferences, automates routines, and optimizes energy usage.
- Runs an **API backend** and a **Flutter app** for control and monitoring.

Do **not** change this fundamental direction.

---

## 2. Tech Stack – What You MUST Use

When generating or modifying code, **stay within this stack** unless the user explicitly asks otherwise:

- **Language**: Python 3.10 (backend), Dart (Flutter frontend)
- **Backend framework**: FastAPI
- **Agents & core logic**: Python modules under `src/agents` and `src/core`
- **Real-time device comms**: MQTT using `paho-mqtt` (and `aiomqtt` where already used)
- **Simulation**: Python-based device simulator + MQTT broker (Mosquitto) + optional Home Assistant
- **Frontend**: Flutter (mobile/web dashboard)
- **Database**: PostgreSQL (via SQLModel / SQLAlchemy)  
- **Migrations**: Alembic (respect and extend migrations instead of ad-hoc SQL)

Do **not** introduce alternative web frameworks, ORMs, or databases unless the user explicitly instructs you.

---

## 3. High-Level Architecture – Invariants

Treat the architecture in the report & repo as **authoritative**:

- **Multi-agent core**:
  - `PlannerAgent`: interprets high-level goals (`/goal` endpoint) and produces a plan.
  - `SensorAgent`: subscribes to MQTT topics (`home/+/+/state`) and updates shared state.
  - `ExecutorAgent`: publishes MQTT commands (e.g. `home/{device_type}/{location}/command`).
  - `MemoryAgent`: tracks history, preferences, anomalies, and higher-level patterns.
  - `SchedulerAgent`: time-based and conditional automation.

- **Shared state / knowledge**:
  - `ContextStore` (in `core/context_store.py`) is the **in-memory, thread- and asyncio-safe source of truth** for device and environment state.
  - Agents **read/write through ContextStore**, not random globals.

- **API Layer**:
  - FastAPI app (e.g. `src/api/api_server.py`) exposes endpoints like:
    - `POST /goal` – send natural language goals.
    - `GET /state` – read full current state snapshot.
    - `GET /devices` – list devices/metadata.
  - Use **Pydantic models** for request/response schemas.

- **Simulation & Devices**:
  - Device simulator (e.g. `simulators/device_simulator.py`) creates many virtual IoT devices that:
    - Subscribe to `home/.../set` (or `/command`) topics.
    - Publish to `home/.../state`.
  - Mosquitto broker is defined in `docker-compose.yml` (port 1883).

When adding new functionality, **extend this architecture, do not replace it**.

---

## 4. Real-Time Communication & Context – Rules

### 4.1 What “real-time” means here

- Real-time **device ↔ backend** communication is handled via **MQTT**.
- Real-time **agent ↔ agent** communication is handled via:
  - MQTT → `SensorAgent` → `ContextStore`
  - Plans → `ExecutorAgent` → MQTT

### 4.2 Do NOT change these behaviors by default

- **Do NOT replace MQTT with WebSockets, gRPC, or raw HTTP** unless explicitly requested.
- **Do NOT remove or bypass `ContextStore`** for state handling.
- **Do NOT make every state read/write go directly to Postgres**, that would break real-time guarantees.

You may add **WebSocket/SSE endpoints** for frontend push **only if the user asks**, and they must read from `ContextStore` (or a light cache) rather than querying Postgres on every event.

---

## 5. Hybrid Persistence Model – ContextStore + PostgreSQL

This is critical:

### 5.1 Source of truth for real-time state

- `ContextStore` remains the **primary, in-memory real-time state store**.
- All agents should continue to:
  - Use `ContextStore.update_state` / `async_update_state` for writes.
  - Use `ContextStore.get_state` / `async_get_state` / `dump[_json]` for reads and snapshots.

### 5.2 Role of PostgreSQL

Postgres is **not a hard real-time store**. Instead, it is for:

- **Durable memory and history**:
  - User interaction logs, routines, anomalies, patterns → owned by **MemoryAgent**.
- **Persistent schedules and rules**:
  - Jobs, routines, and triggers → owned by **SchedulerAgent**.
- **Device metadata and configuration**:
  - Device list, room mapping, capabilities, labels.
- **Periodic snapshots of ContextStore**:
  - Using PoC modules like `db_v2.py` / `migration_v2.py` or their improved successors.

You may:
- Implement **periodic or event-driven snapshotting** from `ContextStore` to Postgres.
- Define clear models for:
  - `Device`
  - `UserPreference`
  - `Routine` / `Schedule`
  - `ContextSnapshot`
  - `ExecutionLog` / `EventLog`

### 5.3 What MUST NOT be persisted at full frequency

Do **not** persist **every single MQTT event / sensor tick** as an individual DB write by default:

- High-frequency telemetry (e.g. temperature every 100ms, motion spam, dimmer changes) should:
  - update `ContextStore` in real time
  - optionally be **downsampled / aggregated** before writing to Postgres.

Avoid designs where:
- Every `SensorAgent` update triggers an immediate blocking `INSERT` or `UPDATE` for each message.

### 5.4 Multi-instance / scaling

If you generate code for multi-instance scaling:

- You may introduce a **sync layer** where:
  - `ContextStore` remains in each process,
  - but important changes are broadcast (e.g. via MQTT or Redis) and/or periodically flushed to Postgres.
- Do not attempt to convert the system into a fully DB-locked state machine without explicit user instruction.

---

## 6. Agents – Behavioral Contracts

When editing/adding agent code:

### PlannerAgent

- Input: natural language goal + context from `ContextStore` + history from `MemoryAgent`.
- Output: a **structured plan**, not raw code.
- Use LLM / prompt engineering consistently with existing patterns.
- Do not hard-code business logic that conflicts with the planner’s LLM-based reasoning unless asked.

### SensorAgent

- Subscribes to MQTT topics (`home/+/+/state` or equivalent).
- On message:
  - Parse topic → identify device, attribute, location.
  - Parse payload (JSON recommended).
  - Update `ContextStore`.
- It should NOT:
  - write directly to Postgres on every message (unless using a buffered/aggregated strategy).
  - bypass the state store.

### ExecutorAgent

- Receives concrete steps from Planner / Scheduler.
- Publishes commands via MQTT.
- Should be **idempotent** where possible (re-sending a command should not break anything).

### MemoryAgent

- Owns:
  - user histories, routines, success/failure logs, anomalies.
- Store long-term data in Postgres using well-defined models.
- Read from `ContextStore` to enrich memory, not the other way around.
- Avoid storing huge raw payloads unnecessarily; prefer summaries and structured records.

### SchedulerAgent

- Owns:
  - scheduled routines (cron-like),
  - delayed tasks,
  - contextual triggers (time-based, simple condition-based).
- Persist its schedule to Postgres so that tasks survive restarts.
- Make scheduling robust and idempotent (avoiding double-triggers after restart).

---

## 7. FastAPI & API Layer – Rules

When modifying API endpoints (e.g. `api_server.py`):

- Preserve existing routes unless the user explicitly approves changes.
- New routes should:
  - Use **Pydantic models** for input/output.
  - Call into agents / ContextStore rather than embedding heavy logic in the route itself.
  - Follow async patterns (`async def`) for I/O-bound work.

- If adding **WebSockets or SSE**:
  - Expose them under a clear path (e.g., `/ws/state`).
  - They should stream changes coming from `ContextStore` or a small cache thereof.

---

## 8. Database & Alembic – Rules

When working on Postgres integration:

- Use **SQLModel / SQLAlchemy** consistently with existing code.
- Always:
  - create or modify models in the models module(s),
  - generate corresponding Alembic migrations (`alembic revision --autogenerate`),
  - ensure `upgrade()` / `downgrade()` are correct.

Do NOT:

- Write manual `CREATE TABLE` / `ALTER TABLE` SQL that bypasses Alembic (unless explicitly asked and justified).
- Introduce a second ORM or separate migration tool.

---

## 9. Simulation & Testing

- Keep the **simulation-first approach**:
  - New features should be testable via the device simulator + MQTT broker.
- When generating tests:
  - Prefer **integration tests** that:
    - spin up agents,
    - simulate MQTT device messages,
    - call API endpoints,
    - assert state in `ContextStore` and/or Postgres where applicable.
- Do not hard-code paths or environment-specific values; use config (`settings.py`) where available.

---

## 10. Frontend (Flutter) – Rules

- The Flutter app communicates with the backend via REST (and possibly WebSockets in the future).
- When generating Flutter code:
  - Use existing API endpoints.
  - Do not assume new endpoints without also updating backend code.
  - Prefer state polling or planned WebSocket usage based on user direction; do not invent a new protocol.

---

## 11. External Integrations (Alexa, Google Home, etc.)

- Treat support for voice platforms (Google Home, Alexa) as an **integration layer around the existing backend**:
  - They should call into the same FastAPI endpoints or MQTT topics.
- Do not build completely separate control flows that bypass the agent system.

---

## 12. Behavior When Asked to “Check” vs “Change”

When the user asks questions like:

- “Is real-time shared knowledge implemented correctly?”
- “Does this follow the architecture?”
- “Where is the ContextStore used?”

You should:

1. **Analyze the existing code**.
2. **Report**:
   - what is implemented,
   - what is missing,
   - where it lives (files, functions, classes).
3. Suggest changes **only after** clearly explaining the current state.

Do not perform large refactors or architecture changes unless the user explicitly asks for them.

---

## 13. Safe Refactoring Boundaries

You **may**:

- Improve logging, error handling, and type hints.
- Extract reusable helpers.
- Add small utilities, models, or endpoints that fit existing patterns.
- Improve performance without changing the overall architecture.

You **must NOT** (unless explicitly requested):

- Replace FastAPI or Flutter.
- Replace MQTT with another protocol.
- Replace ContextStore with a pure DB-backed store.
- Introduce an entirely new architecture or multi-service system.

---

By following these rules, you will help evolve HomeGenie while preserving its agentic, real-time, and simulation-first design.
