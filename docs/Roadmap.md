# Roadmap

This roadmap is intentionally high level. It is not a promise of delivery, investment performance, or trading outcome.

## Current Focus

- Keep the macOS app local-first and owner-governed.
- Preserve clear separation between research, recommendation, approval, and execution.
- Continue hardening public web research provenance for analyst workflows.
- Improve setup clarity for open-source users.
- Keep provider runtimes explicit and provenance-aware.

## Near-Term Public-Readiness Work

- Repeat privacy and secret scans before any public visibility change.
- Keep release artifacts generated from the reviewed public-safe tree rather than hand-maintaining a separate public source of truth.
- Add any missing public-safe sample configuration.
- Verify public build/test instructions on a clean machine.
- Review GitHub repository settings for secret scanning, push protection, branch protection, and vulnerability reporting.

## Possible Future Improvements

- More public-safe sample data and fixtures.
- Broader source adapters for public research.
- Better onboarding around local Keychain setup.
- More granular docs for PM and analyst extension points.
- Expanded UI tests for owner-facing safety surfaces.
- API integrations with additional trading platforms.
- UI polish and onboarding improvements.
- Additional remote communication paths, such as Slack, while preserving transport-only boundaries.
- Open-source/local LLM runtime options and search integrations.
- Adoption of new Swift, SwiftUI, and macOS platform capabilities as they mature.

## Non-Goals

- Publishing private operating state.
- Shipping real credentials or account-specific defaults.
- Promising automated profits.
- Letting model output bypass app-owned safety controls.
- Treating Telegram, PM, analyst, or skill workflows as execution authority.
