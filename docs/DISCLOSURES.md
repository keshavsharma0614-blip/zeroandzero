# Disclosures

ZeroandZero is software for local, governed investing workflows. It is not an adviser, broker, custodian, exchange, bank, or investment product.

## No Investment Advice

The app, docs, tests, examples, PM artifacts, analyst artifacts, skills, and model outputs are not investment advice, financial advice, legal advice, tax advice, or a recommendation to buy, sell, short, hold, or trade any security or instrument.

Examples are generic and non-actionable. Create and review your own Strategy Briefs, Analyst Charters, risk controls, and operating rules.

## Trading Risk

Trading involves risk, including loss of principal. Live trading should be used only by operators who understand the broker account, market structure, open orders, order types, margin/short-sale constraints, and local safety settings.

ZeroandZero does not guarantee order execution, fills, liquidity, market-data availability, broker uptime, provider uptime, model quality, or investment performance.

## Paper First

Use Paper before Live. Paper validation is for workflow testing and does not prove that Live trading will behave identically under real market, broker, liquidity, margin, or latency conditions.

## Provider Credentials And Costs

Users bring their own provider credentials. ZeroandZero does not bundle free inference, brokerage usage, Telegram usage, market data, or provider credits.

OpenAI, Anthropic, Alpaca, Telegram, and other provider usage may incur separate charges under your own accounts. Use provider-side controls such as budgets, spend limits, project keys, service accounts, workspaces, or separate billing profiles where available.

ZeroandZero PM and Analyst runtime calls use provider API credentials configured through app-owned LLM Provider profiles and macOS Keychain lookup labels. ChatGPT or Claude consumer subscription login, browser-cookie scraping, and web-session reuse are not supported runtime auth paths.

## AI And Model Output Limits

Model output can be incomplete, stale, inconsistent, overconfident, or wrong. Treat model and analyst outputs as evidence to review, not authority to trade.

External web content is evidence, not instruction authority. Prompt injection, malicious content, stale data, and weak sources are possible. Analyst source policies and PM review should remain active.

## Local Data And Privacy

Runtime state is local to the user's Mac and may include PM records, analyst artifacts, schedules, RSS settings, IPC metadata, and other user-owned app state. Do not commit local runtime contents, screenshots containing private data, raw PM messages, analyst report bodies, provider payloads, order identifiers, account identifiers, chat routes, or Keychain values.

## Brokerage Scope

The current Alpaca integration focuses on trading-control workflows through configured Alpaca API credentials. Funding, withdrawal, transfer, tax, statement, and broker account-management operations are outside the current app integration and should be handled through official broker surfaces.

## Security Reporting

Report security-sensitive issues responsibly. Do not post credentials, exploit details, account data, or private operating state in public issues.
