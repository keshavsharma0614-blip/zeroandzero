# Safety

ZeroandZero is trading-adjacent software. It is not investment advice, does not promise returns, and should not be used with real capital unless the operator understands and accepts the risks.

## Core Safety Model

- Live trading starts disarmed on every app launch.
- The kill switch blocks Live `NEW` and `REPLACE` orders.
- Live `CANCEL` remains available for risk reduction.
- Manual, strategy, proposal, PM, and analyst-assisted paths all route through the engine order pipeline.
- SwiftUI does not call broker REST APIs directly.
- Streams are authoritative for order lifecycle; REST is used for startup reconciliation, bounded repair, and explicit actions.

## Paper And Live Separation

Paper and Live are separate environments. The app should make the active environment visible before consequential actions. Paper behavior is designed for testing, simulation, and workflow validation. Live behavior is governed by additional safety gates.

## Local User Presence

The app can require macOS local authentication before Live order submission. When enabled:

- Live `NEW` and Live `REPLACE` require a fresh Touch ID or Mac password challenge,
- disabling the protection requires local authentication,
- Paper orders are unaffected,
- Live `CANCEL` remains available.

The app uses Apple's LocalAuthentication framework. It receives only success or failure; it does not see or store biometric data or Mac passwords.

## PM And Analyst Boundaries

PM and analyst workflows can reason, research, recommend, and create artifacts. They do not create trading authority by themselves.

- The PM is the owner-facing coordinator. It communicates with the owner and can propose or prepare consequential actions only through governed app workflows.
- The PM is not the web-research worker and does not directly execute orders. External research is mediated through analyst artifacts and app-owned review paths.
- Standing analysts are research workers. They may perform external web research when their charters permit it, then return source-backed reports, findings, recommendations, or artifacts to the PM/app.
- Analysts do not place orders, approve Live execution, or convert internet-sourced content directly into trades.
- Analyst reports are research artifacts.
- PM decisions and approval requests are coordination records.
- Agent Skills are methodology guidance.
- Telegram is transport only.
- No PM, analyst, skill, Telegram, or provider output can bypass live arming, kill switch, LocalAuthentication, proposal review, PM approval, or engine order gates.

This separation reduces prompt-injection blast radius: external content can inform a report, but it cannot silently become strategy truth, approval truth, or a trade.

## Secrets

Supported credential flows expect secrets in macOS Keychain. Repository files, logs, IPC responses, diagnostics, screenshots, issues, and pull requests must not contain:

- Alpaca keys or account identifiers,
- OpenAI or Anthropic API keys,
- Telegram bot tokens or chat routes,
- GitHub tokens,
- raw PM messages,
- private runtime state,
- private strategy or report bodies.

## Public Web And Research Sources

Analyst research treats external content as evidence, not instruction authority. Official/primary evidence is preferred. Reputable secondary or domain sources may be used only when the selected analyst charter permits them, and must be labeled.

## Operator Responsibility

Before using Live mode, verify:

- credentials and environment,
- paper/live status,
- kill-switch status,
- live arming status,
- open orders,
- account and market-data readiness,
- LocalAuthentication setting,
- proposal and approval lineage.

Do not rely on model output as a substitute for owner review.
