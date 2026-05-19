# Architecture

This document describes the public project architecture at a current-state level. It intentionally avoids private development history and local operating data.

## Design Goals

ZeroandZero is a local-first macOS trading workstation with an agentic research layer. The app is designed around three principles:

- the app is the durable control plane,
- all trading actions pass through engine-owned safety gates,
- PM and analyst workflows create reviewable artifacts, not trading authority.

## Main Components

### macOS SwiftUI App

The SwiftUI app provides the owner-facing surfaces:

- Command Center for daily posture, PM conversation, analyst controls, skills, and background activity,
- Portfolio Watch for watchlist and portfolio state,
- News for local normalized news review,
- System Control for runtime, storage, credentials, safety, and operational posture,
- advanced review surfaces such as PM Inbox, manual orders, proposals, jobs, and logs.

The UI reads from `AppModel`, which adapts `TradingKit.Store` snapshots into presentation state. UI code must not call broker REST APIs directly.

### TradingKit Engine

`TradingKit.Engine` is the UI-agnostic app core. It owns:

- app startup and shutdown,
- Alpaca REST and WebSocket integration,
- live/paper environment checks,
- order submission, replacement, and cancel paths,
- kill-switch and live-arming gates,
- LocalAuthentication live execution protection,
- local IPC server,
- scheduler and job coordination,
- PM and analyst persistence seams.

Manual orders, proposal execution, strategy paths, and agent-assisted execution all converge through the engine order pipeline.

### Store

`TradingKit.Store` is the central event-driven truth layer for app state and UI projections. Broker streams are authoritative for order lifecycle, while REST is used for startup reconciliation, bounded repair, and explicit user actions.

### Broker And Market Data

The app integrates with Alpaca for:

- account, order, position, asset, and contract REST calls,
- trade update WebSocket events,
- market-data WebSocket streams for quotes, trades, and bars.

Market data uses a shared multiplexed stream. Desired subscriptions, acknowledged subscriptions, and usable Store prices are tracked separately so the UI can distinguish "requested" from "actually receiving data."

### PM Layer

The PM layer coordinates owner conversation, app-owned truth, analyst work, and governed recommendations. PM messages, decisions, approval requests, delegation records, notebook entries, and instructions are durable app-owned records.

PM/User meaning is model-first. Deterministic code validates hidden actions, applies safe mutations, and enforces governance. The PM cannot approve trades, bypass proposal review, bypass live arming, bypass the kill switch, bypass LocalAuthentication, or place trades outside the engine order pipeline.

The PM is the owner-facing coordinator, not the open-web research worker and not an execution surface. It can propose or prepare consequential actions only through governed app workflows. External research flows through analyst artifacts and app-owned review paths before it can inform PM synthesis.

### Analyst Layer

Analysts are durable app-owned roles with charters, tasks, memos, evidence bundles, findings, standing reports, and skill usage summaries. Analyst work can be launched manually, by schedule, or through PM delegation.

Analyst research is charter-governed. The shared source ladder is:

1. app-owned truth,
2. official or primary public sources,
3. reputable public domain or secondary sources when the charter permits,
4. explicit missing, restricted, or unsupported source gaps.

Primary/official evidence is preferred and labeled. Primary-only behavior applies only when the owner task or charter explicitly requires it.

Analysts may research externally when their charters and the task allow it, but their outputs remain bounded artifacts. Analysts do not place orders, approve Live execution, or directly mutate strategy truth. This PM/Analyst separation limits the blast radius of prompt injection or compromised internet-sourced content.

### Agent Skills

Agent Skills are reusable, owner-editable methodology documents. They may be attached to analyst charters or selected by PM tasking, then included in analyst context packs. Skills do not grant source access, tool access, approval authority, or trading authority.

### Provider Runtime

LLM runtime configuration is provider-aware. OpenAI and Anthropic paths use TradingKit-owned runtime seams and macOS Keychain lookup profiles. Provider calls do not originate directly from SwiftUI, and provider provenance is recorded on generated artifacts.

PM and Analyst runtimes use owner-managed provider API credentials. They do not use ChatGPT or Claude consumer account login, browser-cookie scraping, web-session reuse, or unsupported subscription-backed runtime auth. That boundary keeps model usage explicit, revocable, auditable, and separated from browser session state.

### Persistence

The app stores local records under the user's local macOS app data directory. Secrets are not stored there; supported credential flows read from macOS Keychain. Persistence formats are schema-versioned and designed for local-first operation.

### IPC

The local control plane is a loopback-only HTTP IPC server. It writes runtime metadata to a local file, requires an `X-Agent-Token`, and returns JSON envelopes. IPC is for local tools and worker processes, not remote public access.

## Safety Boundary

The app separates research and recommendation from execution:

- PM and analyst outputs are not orders.
- Signals are not proposals.
- Proposals are not approvals.
- Approvals are not live execution unless all engine safety gates pass.
- Live `NEW` and `REPLACE` paths are blocked unless live is armed, kill switch is off, and any enabled local user-presence gate succeeds.
- Live `CANCEL` remains available for risk reduction.

See [Safety.md](Safety.md) for details.
