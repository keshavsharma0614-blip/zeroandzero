# Development

This document describes the public development workflow for building and testing the project.

## Repo Layout

```text
MacApp/AlgoTradingMac/        macOS SwiftUI app
Packages/TradingKit/         Swift package with engine, store, integrations, IPC, tests
docs/                         public-facing docs
scripts/                      optional local diagnostic helper scripts
```

## Build

```bash
xcodebuild -workspace AlgoTradingMac.xcworkspace -scheme AlgoTradingMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## App Tests

```bash
xcodebuild -workspace AlgoTradingMac.xcworkspace -scheme AlgoTradingMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:AlgoTradingMacTests
```

## TradingKit Tests

```bash
cd Packages/TradingKit
swift test
```

## Local IPC Smoke

With the app not running, this should fail cleanly with a missing-runtime response:

```bash
cd Packages/TradingKit
swift run alpaca_agentctl status
```

With the app running, it should return status JSON from the local loopback IPC server.

## Development Rules

- Keep changes small and testable.
- Preserve the UI-agnostic engine and central Store architecture.
- Do not let SwiftUI call broker REST directly.
- Do not commit local runtime state or secrets.
- Update docs when contracts change.
- Keep PM, analyst, provider, Telegram, and order-execution boundaries explicit.
