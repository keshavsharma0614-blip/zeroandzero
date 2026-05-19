# Persistence

ZeroandZero stores local app-owned state in schema-versioned files under the user's local macOS app data directory.

## Location

Typical local root:

This directory is user-owned runtime state. Do not commit it.

## What Is Persisted

Depending on enabled features, local persistence may include:

- proposals and paper-run records,
- PM records,
- analyst tasks, memos, reports, evidence bundles, and charters,
- Agent Skills,
- runtime settings and schedules,
- RSS/news records,
- audit and job telemetry,
- portfolio/watchlist configuration.

## What Is Not Persisted In Repo Files

The repository should not contain:

- real credentials,
- Keychain secret values,
- Telegram routes,
- account identifiers,
- raw private PM conversations,
- private strategy documents,
- private analyst report bodies,
- local runtime data.

## Compatibility

Stores use schema-versioned wrappers where practical. Unknown or corrupt records should fail safely with bounded diagnostics instead of crashing broad app startup.

## Cleanup

Maintenance flows should use app-owned retention/cleanup paths. Do not manually delete user data as part of normal app operation without an explicit retention or migration plan.
