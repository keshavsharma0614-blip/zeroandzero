# Alpaca Endpoints

This document summarizes the Alpaca integration points used by the app. Always consult Alpaca's current official documentation before relying on endpoint details in production.

## Environments

Trading REST:

- Paper: `https://paper-api.alpaca.markets`
- Live: `https://api.alpaca.markets`

Trade updates WebSocket:

- Paper: `wss://paper-api.alpaca.markets/stream`
- Live: `wss://api.alpaca.markets/stream`

## Market Data

Market data uses Alpaca's market-data streaming hosts and feed-specific channels. The app keeps one multiplexed stream and reconciles subscriptions incrementally.

The app tracks:

- requested symbols,
- acknowledged active subscriptions,
- latest usable Store quote/trade/bar data.

These are separate truths so the UI can report degraded or waiting states honestly.

## Common Trading REST Areas

The app uses Alpaca REST behind the engine boundary for account, positions, open orders, assets, contract lookup, and explicit order actions.

Supported order actions must pass through the engine order pipeline. Strategies and SwiftUI surfaces must not call Alpaca REST directly.

## Headers

Alpaca requests use API key headers. Real header values must come from local credentials, not repository files:

```text
APCA-API-KEY-ID: <your key id>
APCA-API-SECRET-KEY: <your secret key>
```

## Rate Limiting

REST throttling is enforced at the engine/client boundary. Do not bypass it from UI or strategy code.
