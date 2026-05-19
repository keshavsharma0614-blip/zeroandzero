# IPC

The app exposes a local loopback IPC server for command-line tools and worker processes.

## Boundary

- The server binds to loopback only.
- Requests require an `X-Agent-Token`.
- Runtime metadata is local session state and must not be committed.
- IPC does not create trading authority by itself.

## Runtime Metadata

When the app runs, it writes metadata under its local runtime data directory so local tools can discover:

- host,
- port,
- session token,
- build/runtime summary.

The token is local runtime state. Do not include it in docs, screenshots, logs, issues, or commits.

## JSON Envelopes

Routes return JSON envelopes with success or error information. Error payloads should be precise enough for local tooling without exposing secrets, account identifiers, raw provider payloads, raw PM messages, Telegram routes, or raw report bodies.

## Typical Uses

- `alpaca_agentctl status`
- local smoke checks,
- analyst worker handoff,
- maintenance commands,
- schedule/job inspection.

## Route Catalog

The supported local routes are listed here as a public API contract. Request and response bodies are JSON envelopes and must remain bounded; do not include credentials, account identifiers, raw provider payloads, raw PM messages, Telegram routes, or raw report bodies.

### Core

- GET `/status`
- GET `/strategies`
- GET `/proposals`
- GET `/proposal`
- GET `/runs`
- GET `/jobs`
- GET `/schedules`
- GET `/schedule`
- GET `/retention-policy`
- GET `/maintenance/last`
- GET `/rss/feeds`
- GET `/news`
- GET `/signals`
- GET `/run`
- GET `/job`
- GET `/signal`

### PM Records

- GET `/pm/profiles`
- GET `/pm/profile`
- POST `/pm/profile/upsert`
- GET `/pm/mandates`
- GET `/pm/mandate`
- POST `/pm/mandate/upsert`
- GET `/pm/instructions`
- GET `/pm/instruction`
- POST `/pm/instruction/upsert`
- GET `/pm/notebook`
- GET `/pm/notebook-entry`
- POST `/pm/notebook-entry/upsert`
- GET `/pm/portfolio-strategy-brief`
- POST `/pm/portfolio-strategy-brief/upsert`
- GET `/pm/decisions`
- GET `/pm/decision`
- POST `/pm/decision/upsert`
- GET `/pm/approval-requests`
- GET `/pm/approval-request`
- POST `/pm/approval-request/upsert`
- GET `/pm/execution-readiness`
- POST `/pm/execution/route`
- GET `/pm/communication-sessions`
- GET `/pm/communication-session`
- POST `/pm/communication-session/upsert`
- GET `/pm/communication-messages`
- GET `/pm/communication-message`
- POST `/pm/communication-message/upsert`
- GET `/pm/delegations`
- GET `/pm/delegation`
- POST `/pm/delegation/upsert`
- POST `/pm/delegation/follow-up`
- POST `/pm/delegation/launch`

### Analyst Records

- GET `/analyst/charters`
- GET `/analyst/charter`
- POST `/analyst/charter/upsert`
- GET `/analyst/source-access-suggestions`
- GET `/analyst/source-access-suggestion`
- POST `/analyst/source-access-suggestion/upsert`
- GET `/analyst/tasks`
- GET `/analyst/task`
- POST `/analyst/task/upsert`
- GET `/analyst/findings`
- GET `/analyst/finding`
- GET `/analyst/memos`
- GET `/analyst/memo`
- GET `/analyst/news`
- POST `/analyst/evidence-bundle/upsert`
- POST `/analyst/memo/upsert`
- POST `/analyst/finding/upsert`
- POST `/analyst/signal/draft-proposal`

### Jobs, Schedules, And Maintenance

- POST `/jobs/submit`
- POST `/job/cancel`
- POST `/schedule/upsert`
- POST `/schedule/remove`
- POST `/schedule/enable`
- POST `/schedule/run-now`
- POST `/retention-policy/update`
- POST `/maintenance/run`
- POST `/maintenance/memory-relief`

### News And Signals

- POST `/signal/ack`
- POST `/signal/archive`
- POST `/rss/feed/add`
- POST `/rss/feed/update`
- POST `/rss/feed/remove`

### Strategy, Proposals, Replay, And Safety

- POST `/strategy/start`
- POST `/strategy/start-from-proposal`
- POST `/strategy/stop`
- POST `/strategy/params`
- POST `/proposal/upsert`
- POST `/proposal/submit`
- POST `/proposal/approve-paper`
- POST `/proposal/deny-paper`
- POST `/run/export`
- POST `/replay/ingest`
- POST `/replay/run`
- POST `/replay/quick`
- POST `/safety/arm-live`
- POST `/safety/disarm-live`
- POST `/safety/kill-switch`

## Safety

IPC requests still flow through engine validation. Headless IPC must not bypass Live arming, kill switch, LocalAuthentication, proposal review, PM approval, or other app-owned gates.
