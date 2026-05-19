# Replay

Replay support lets developers exercise strategy and execution logic against historical bars without placing live orders.

## Purpose

Replay is for deterministic development and validation. It is not a guarantee of future performance.

## Components

- historical bar ingestion,
- local bar cache,
- replay runner,
- optional simulated broker behavior,
- run records and metrics.

## Safety

Replay mode must not submit real broker orders. It is separate from Paper and Live broker execution.

## Determinism

Replay runs should use explicit inputs such as symbols, dates, bar data, and strategy configuration. Re-running the same scenario with the same inputs should produce stable results where the code path is deterministic.

## Limitations

Replay cannot fully model live liquidity, slippage, exchange behavior, partial fills, outages, broker limits, or market-data subscription behavior.
