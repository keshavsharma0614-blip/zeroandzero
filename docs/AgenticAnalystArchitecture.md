# Agentic Analyst Architecture

The analyst layer turns app-owned context, charter rules, selected skills, and bounded public evidence into reviewable research artifacts.

## Analyst Charters

An Analyst Charter defines the analyst's lane, responsibilities, source policy, and boundaries. Charters are durable app-owned records and are distinct from PM memory, strategy documents, skills, reports, and trading authority.

## Tasks And Reports

Analyst work can produce:

- task records,
- readable memos,
- evidence bundles,
- findings,
- standing reports,
- skill usage summaries.

These artifacts are review inputs. They are not orders, approvals, or trading instructions.

## Research Source Ladder

Analyst research follows a shared source ladder:

1. app-owned truth,
2. official or primary public sources,
3. reputable public domain or secondary sources when the charter permits,
4. explicit source gaps for missing, restricted, or unsupported evidence.

Primary evidence is preferred but not mandatory unless the charter or current owner task requires primary-only research. Secondary evidence must be labeled and must not be represented as official evidence.

Standing analysts are the research workers for external web research when their charters and the current task allow it. They produce source-backed artifacts for PM/app review; they do not directly update strategy truth, approve execution, or place trades.

## Agent Skills

Agent Skills are reusable methodology documents. A charter may reference skills as available, recommended, or required. PM tasking may also request selected active skills for a specific task.

The analyst context pack includes full bodies only for selected active skills, not every skill in the library. Skill usage is recorded back onto generated artifacts when applicable.

## Provider Runtime

Analyst synthesis can run through configured provider runtimes behind TradingKit seams. Runtime provenance is recorded. Provider output is validated before it is persisted as app-owned analyst truth.

## Governance

Analysts cannot:

- grant themselves new tools or source permissions,
- override source policy,
- approve trades,
- place orders,
- bypass Live safety gates,
- convert research into execution authority.

This separation limits the blast radius of prompt injection or compromised internet-sourced content. External research can inform a report, but consequential actions remain mediated by app-owned truth, owner review, Engine routing, Live arming, kill switch, and LocalAuthentication when enabled.
