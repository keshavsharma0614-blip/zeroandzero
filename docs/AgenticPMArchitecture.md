# Agentic PM Architecture

The PM layer coordinates owner conversation, app-owned truth, analyst work, and governed recommendations.

## Role

The PM can:

- answer owner questions using app-owned context,
- request analyst work through validated actions,
- summarize analyst artifacts,
- create durable PM records such as decisions, approval requests, notebook entries, instructions, and delegations.

The PM cannot:

- approve trades by itself,
- browse the open web or perform external web research directly,
- bypass proposal review,
- bypass Live arming, kill switch, or LocalAuthentication,
- place orders outside the engine order pipeline,
- treat Telegram transport as authority.

The PM is not the web-research worker and does not directly execute orders. External research is mediated through analyst artifacts and app-owned review paths, then the PM can synthesize that material for the owner.

## Meaning And Actions

Owner/PM conversation meaning is model-first. The app may ask the model for a visible reply and a hidden action plan. Deterministic code then validates and safely applies any requested durable mutation.

Consequential app actions require:

- exact app-owned target ids where applicable,
- valid state transitions,
- governance checks,
- clear owner-facing follow-through.

## Context

PM context is assembled from bounded app-owned truth, such as:

- environment and safety posture,
- portfolio/watchlist state,
- provider/runtime status,
- recent PM and analyst artifacts,
- active Agent Skill index when relevant,
- operating guidance and analyst roster.

The app should not dump raw private history into every prompt. Retrieval is bounded and task-shaped.

## Analyst Tasking

The PM can task analysts when it emits a valid delegation action with a real analyst or charter target. Selected Agent Skills may be attached to that task, but they remain methodology guidance and do not mutate the analyst charter unless a separate explicit owner action does so.

If no valid analyst target exists, the PM should ask a focused routing question or report the blocker. It should not imply work has launched without an app-owned task.

## Source And Research Contract

For research requests, the selected analyst charter governs research breadth. The PM should choose the closest valid analyst lane when the broad domain fit is clear and avoid inventing bespoke research routes.

The PM/Analyst boundary is part of the safety model. Internet-sourced content can reach the PM through analyst reports, evidence summaries, and source-backed findings, but it cannot directly become a trade, approval, or durable strategy change without app-owned validation and owner review.

## PM Artifacts

PM records are local durable coordination artifacts. They remain separate from:

- analyst reports,
- signals,
- proposals,
- broker orders,
- approvals,
- strategy documents,
- local credentials.
