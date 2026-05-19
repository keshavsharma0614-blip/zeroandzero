# Contributing To ZeroandZero

Thanks for helping improve ZeroandZero.

This repository is intended to stay readable, buildable, and public-safe. Contributions should stay small, explicit, and easy to review.

## Working Style
- Prefer small bounded changes over large refactors.
- Keep changes easy to verify with code, tests, and documentation.
- Preserve the core architecture:
  - UI-agnostic `TradingKit` engine plus central store
  - single order pipeline
  - authoritative stream-driven market state
  - governed safety shell around consequential actions
- Do not introduce features that blur source-of-truth boundaries between the app, PM, analyst worker, and transport surfaces.

## Build And Test Expectations
Run the standard checks before proposing a change:

```bash
xcodebuild -workspace AlgoTradingMac.xcworkspace -scheme AlgoTradingMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace AlgoTradingMac.xcworkspace -scheme AlgoTradingMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:AlgoTradingMacTests
cd Packages/TradingKit && swift test
```

If you change docs or public-facing examples, re-read the affected docs for private data, credentials, and investment-advice wording before opening a pull request.

## Public-Safe Contribution Rules
- Never commit secrets, tokens, or credentials.
- Never commit private runtime data, conversation history, or local operating state.
- Do not add internal notes, local debug journals, or private operating records.
- Keep Telegram, PM, analyst, runtime, and schedule assumptions user-configured rather than hardcoded.
- Preserve the rule that public RSS feeds are allowed only when they are public-safe and intentionally repo-tracked.

## Pull Requests
When opening a PR:
- describe the bounded problem being solved
- explain any architectural or safety implications
- list the verification commands you ran
- call out any public-safety, trading-safety, credential, or persistence implications

## Need More Context?
Start with:
- [README.md](README.md)
- [docs/Architecture.md](docs/Architecture.md)
- [docs/Safety.md](docs/Safety.md)
- [docs/Configuration.md](docs/Configuration.md)
- [docs/Development.md](docs/Development.md)
