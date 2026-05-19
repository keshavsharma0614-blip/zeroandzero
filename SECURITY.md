# Security Policy

ZeroandZero is a local macOS control plane for governed investing workflows. Security work should preserve the central safety thesis: agents may reason and recommend, but durable truth, credentials, approvals, audit state, Live posture, and execution gates remain app-owned and owner-governed.

## Reporting A Vulnerability

Please do not post sensitive security issues, credentials, exploit details, account data, Telegram routes, raw PM messages, or private operating state in a public issue.

Until a dedicated public reporting channel is published for `zeroandzero-ai/zeroandzero`, use one of these safer paths:

- GitHub private vulnerability reporting, if it is enabled for the repository
- a direct maintainer contact path shared in the repository metadata

Include:

- affected version or commit
- clear reproduction steps
- impact assessment
- any mitigation ideas you already tested

## Security Posture Overview

ZeroandZero is designed as a thick local harness around investment-adjacent agent workflows:

- local-first macOS app control plane,
- Keychain-backed credential lookup,
- bounded PM and analyst agency,
- app-owned persistence and audit/provenance records,
- single governed Engine order pipeline,
- Paper/Live environment separation,
- Live starts disarmed,
- kill switch for Live `NEW` and `REPLACE`,
- optional LocalAuthentication gate before Live order submission.

These controls reduce risk; they do not eliminate trading risk, model error, prompt injection, credential compromise, brokerage risk, local machine compromise, or user error.

## Local-First Control Plane

Runtime state is local to the user's Mac. The app stores user-owned operating records under its local runtime data directory and uses macOS Keychain for supported secret flows. The public repo must not become a sink for private runtime data, credentials, raw provider payloads, order/account identifiers, Telegram routes, PM messages, analyst reports, or screenshots containing private state.

## Keychain-Only Secrets

Supported credential flows expect secrets in macOS Keychain, not source files, docs, logs, IPC responses, screenshots, issues, or pull requests.

Sensitive values include:

- Alpaca API keys and account identifiers,
- OpenAI and Anthropic API keys,
- Telegram bot tokens and chat identifiers,
- GitHub or CI tokens,
- broker order identifiers,
- raw provider payloads,
- private strategy/report bodies.

If a secret is exposed outside Keychain, rotate it at the provider or broker. Deleting it from the current tree is not enough if it reached git history, logs, screenshots, or a public issue.

## Provider Runtime Boundary

PM and Analyst runtime calls use owner-managed provider API credentials configured through macOS Keychain lookup profiles. ZeroandZero does not use ChatGPT account login, Claude account login, browser cookies, or consumer subscription sessions as runtime credentials.

This is a security and operability boundary. API credentials can be rotated, scoped, audited, and budgeted through provider controls where available. Browser session state and consumer subscription login are not treated as generic authority for a governed investing app.

OpenAI, Anthropic, Alpaca, Telegram, and other provider usage may incur charges under the user's own accounts. ZeroandZero does not bundle free inference or provider usage.

## PM/Analyst Agency Separation

The PM is the owner-facing coordinator. It can communicate with the user, synthesize app-owned context, task analysts through validated actions, and propose or prepare consequential actions through governed app workflows.

The PM is not the open-web research worker and does not directly execute orders. Standing analysts are the research workers that may perform external web research when their charters and the current task allow it.

Analysts produce source-backed reports, findings, recommendations, and artifacts back to the PM/app. Analysts do not place orders, approve Live execution, arm Live, bypass the kill switch, or mutate durable strategy truth by themselves.

This separation limits prompt-injection blast radius: external content can inform analyst artifacts, but it cannot directly become a trade, approval, or app-owned truth without review and validation.

## Telegram Transport Boundary

Telegram is optional and transport-only. It is a remote communication path into app-owned PM communication records, not PM memory, approval truth, workflow truth, or trading authority.

Telegram cannot:

- final-approve Live trades,
- arm Live,
- bypass the kill switch,
- bypass proposal or order review,
- bypass LocalAuthentication,
- become the durable source of strategy or approval truth.

Users should create their own bot through BotFather, store the bot token through the supported app credential path, complete the in-app authorization/binding flow, and keep bot tokens and chat identifiers private.

## IPC Authority Limits

The local IPC server is a loopback control surface for local tools and worker processes. It requires the app-issued local token and should return bounded JSON envelopes. IPC responses must avoid credentials, account identifiers, raw provider payloads, raw PM messages, Telegram routes, raw report bodies, and private runtime contents.

IPC must not bypass Live arming, the kill switch, LocalAuthentication, proposal review, PM approval, or Engine order gates.

## Engine Order Pipeline

Manual orders, proposal execution, strategy paths, and agent-assisted execution converge through the Engine order pipeline. SwiftUI should not call broker REST APIs directly. PM, analyst, skill, Telegram, provider, and IPC outputs are inputs to reviewable workflows; they are not orders by themselves.

## Paper/Live Separation

Paper and Live are separate environments. Live starts disarmed on app launch. Live `NEW` and `REPLACE` are blocked unless Live is armed, the kill switch is off, required proposal/approval gates are satisfied, and any enabled local user-presence gate succeeds. Live `CANCEL` remains available for risk reduction.

## LocalAuthentication / Biometric Gate

Live execution can require macOS LocalAuthentication using Touch ID or the Mac password where available and configured. The app receives only success or failure from the operating system. It does not see, receive, or store fingerprint data or Mac passwords.

LocalAuthentication is a local OS authorization gate. It is not a substitute for owner review, proposal approval, brokerage controls, credential hygiene, or risk management.

## Audit And Provenance

Generated PM and analyst artifacts should carry enough provenance for review: provider/runtime status, source summaries, approval lineage, routing outcomes, and execution blockers where applicable. Audit/provenance records are app-owned local records. They should help the operator understand what happened without exposing secrets or raw private payloads into public surfaces.

## Known Limitations And User Responsibilities

Users remain responsible for:

- securing the Mac and local account,
- protecting Keychain access,
- configuring provider/broker/Telegram credentials safely,
- setting provider and broker-side budgets/limits where available,
- reviewing PM/analyst outputs before action,
- understanding broker account, margin, short-sale, market-data, and order risks,
- keeping private operating state out of public issues and pull requests.

ZeroandZero is not immune to prompt injection, model error, stale data, compromised credentials, brokerage outages, market-data outages, provider downtime, or user mistakes. It is not investment advice.

## Scope Note

This repository intentionally omits private operational data, but security-sensitive bugs can still exist in code, bootstrap docs, examples, or tooling and should be reported responsibly.
