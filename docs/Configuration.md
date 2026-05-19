# Configuration

ZeroandZero is local-first. You provide your own external accounts, credentials, runtime settings, feeds, and operating documents.

## macOS Requirements

- macOS with Xcode and Swift toolchain installed.
- A local user account capable of storing credentials in macOS Keychain.
- Optional Touch ID or Mac password setup for local Live execution protection.

## Local State

Runtime state is stored under the user's local macOS app data area.

Do not commit files from this directory. It may contain local runtime metadata, PM records, analyst artifacts, schedules, RSS settings, and other user-owned app state.

## LLM Runtime Authentication And Costs

ZeroandZero uses provider API credentials for PM and Analyst runtime calls. Users bring their own OpenAI and/or Anthropic API credentials. The app's LLM Provider profiles persist only Keychain lookup labels, readiness summaries, provider kind, and runtime/model preferences. They do not persist API keys.

Supported public runtime-auth shape:

- OpenAI API credentials stored through supported app Keychain-backed profiles.
- Anthropic API credentials stored through supported app Keychain-backed profiles.
- Provider/runtime settings selected locally by the owner.

Not supported:

- ChatGPT Plus, Pro, Business, Team, or Enterprise login as PM/Analyst runtime auth.
- Claude Pro, Max, Team, or Enterprise login as PM/Analyst runtime auth.
- browser-cookie scraping.
- ChatGPT or Claude web-session reuse.
- unsupported subscription-backed API access.
- product-specific ChatGPT, Codex, Claude, or Claude Code login reuse as a generic runtime adapter.

This is intentional. ZeroandZero is a governed investing control plane, so runtime calls should use stable provider API boundaries that are auditable, revocable, project-scoped where supported, and separate from browser session state.

ZeroandZero does not include or subsidize inference. OpenAI and Anthropic API calls may create provider-side usage charges under your account. Provider usage, provider rate limits, provider availability, and inference costs remain your responsibility. Use provider-side controls such as project keys, service accounts, workspaces, budgets, spend limits, prepaid credits, or separate billing profiles where available.

If provider credentials are missing or unavailable, ZeroandZero should report explicit degraded or local fallback behavior. Missing credentials are not a hidden path to subscription-backed runtime auth.

### Alpaca

Configure your own Alpaca Paper and, if needed, Live API credentials in Keychain using the labels expected by the app code. Check the current `KeychainCredentialsProvider` implementation before use.

Never store Alpaca keys in source files, issue text, screenshots, logs, or exported docs.

### OpenAI And Anthropic

Use the app's LLM provider settings to configure OpenAI and Anthropic profiles. Each profile points to a macOS Keychain service/account lookup and selects the desired provider/model behavior. The profile stores lookup labels and readiness metadata only; the secret value stays in Keychain.

Do not commit OpenAI or Anthropic API keys.

### Telegram

Telegram is optional and transport-only. It is a remote communication surface into the same app-owned PM communication records, not PM memory, approval truth, workflow truth, or trading authority.

If you enable Telegram:

1. Create a bot through Telegram BotFather.
2. Store the bot token through the supported app credential path.
3. Start the app and complete the in-app Telegram authorization/binding flow by sending the bot a fresh message and polling updates so the app can learn the intended chat route.
4. Confirm System Control shows the expected Telegram owner route before relying on Telegram continuity.
5. Keep bot tokens, chat identifiers, screenshots, and routing details out of source files, issues, logs, and docs.

Telegram cannot final-approve Live trades, arm Live, bypass the kill switch, bypass proposal review, bypass the Engine order pipeline, or bypass LocalAuthentication. Telegram approval-style replies resolve through app-owned approval records and still remain below the local Live execution gates.

### Advanced / Developer Notes

Credential labels below are examples of Keychain service/account names, not secret values. Prefer supported app settings screens or documented local setup flows where available.

The default OpenAI Keychain profile currently uses:

```text
service: open_api_key
account: algo-trading
```

Some migration paths may also recognize:

```text
service: openai_api_key
account: algo-trading
```

The default Anthropic Keychain profile currently uses:

```text
service: anthropic_api_key
account: algo-trading
```

The Telegram bot token lookup currently uses:

```text
service: telegram.api.key
account: algo-trading
```

## FAQ

### Can I use my ChatGPT Plus, Pro, Business, Team, or Enterprise login instead of an OpenAI API key?

No. ZeroandZero's PM and Analyst runtimes use OpenAI API-compatible credentials, not ChatGPT consumer or workspace session login. ChatGPT subscriptions and OpenAI API usage are separate provider products and billing surfaces. Some developer tools may support product-specific login flows, but ZeroandZero intentionally uses API credentials for stability, auditability, revocation, and governed investing safety.

If OpenAI later offers an official delegated API authorization path suitable for local third-party apps, it can be evaluated as a future provider auth kind.

### Can I use my Claude subscription instead of an Anthropic API key?

No. ZeroandZero's Anthropic runtime paths use Claude API credentials configured through Keychain lookup profiles. Claude chat subscriptions do not replace Anthropic Console/API access for this app. If Anthropic later exposes an official delegated API authorization path suitable for local third-party apps, it can be evaluated as a future provider auth kind.

## Runtime Settings

Provider/runtime settings are local app-owned records. The public repo does not ship private runtime preferences. Configure PM, standing analyst, and Recent News analyst runtime settings locally.

## Strategy, Charters, Skills, And Feeds

The public repo may ship public default RSS/feed source configuration when the sources are public, non-tokenized, non-account-specific, and intentionally repo-tracked. It does not ship private operating documents, private/user-specific feed state, tokenized feed URLs, or fetched article history.

You may configure:

- strategy documents,
- analyst charters,
- Agent Skills,
- watchlists,
- schedules,
- public-safe RSS/feed sources,
- provider profiles.

Only commit public-safe examples if they are intentionally repo-tracked and contain no private operating content.

## IPC Runtime Metadata

When the app runs, it writes local IPC metadata under its local runtime data directory. This includes a session token used by local tools. Treat it as local runtime state and do not commit it.
