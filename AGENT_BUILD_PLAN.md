# Agent Expansion Build Plan

This plan adds two agents without changing the current runtime path yet:

- `Provider Ranking Agent`
- `Referral Handoff Agent`

The goal is to improve provider quality deterministically and generate a referral-ready export packet from the existing session state.

## Current Pipeline

`Conversation Agent -> Intervention Agent -> Calling Agent -> Diagnosis Agent -> Messaging Agent`

Export path today:

`export_pdf walker -> services/pdf_exporter.build_session_pdf_payload(session)`

## Proposed Pipeline

Primary response path:

`Conversation -> Intervention -> Calling -> Diagnosis -> Provider Ranking -> Messaging -> Summary`

Export path:

`export_pdf -> Referral Handoff -> pdf_exporter`

This keeps model usage flat because ranking is deterministic and the handoff packet is assembled from existing structured data.

## 1. Provider Ranking Agent

Agent name:

`Provider Ranking Agent`

Input:

- `session: UserSession`
- `diagnosis: DiagnosisResult`
- `providers: list[ProviderOption]`

Output:

- `list[RankedProvider]`
- side effect: updates `session.ranked_provider_options`
- side effect: rewrites `session.provider_options` in ranked order

Schema:

- `RankedProvider.provider: ProviderOption`
- `RankedProvider.score: float`
- `RankedProvider.reasons: list[str]`

Where it plugs into the pipeline:

- File: [agents/diagnosis.jac](/Users/sarthakpatel/CareAnchor/agents/diagnosis.jac)
- Insert immediately after `session.provider_options = providers;`
- Then call `apply_provider_ranking(session, result);`

Why this seam is correct:

- It already has `DiagnosisResult`
- It already owns provider lookup
- It does not require any new LLM call

Jac scaffold:

- File: [agents/provider_ranking.jac](/Users/sarthakpatel/CareAnchor/agents/provider_ranking.jac)
- Main entrypoints:
  - `rank_provider_options(session, diagnosis, providers)`
  - `apply_provider_ranking(session, diagnosis)`

Recommended scoring dimensions:

- specialty match
- insurance match
- accepting new patients
- telehealth availability
- distance bucket
- rating bucket

## 2. Referral Handoff Agent

Agent name:

`Referral Handoff Agent`

Input:

- `session: UserSession`

Output:

- `ReferralHandoffPacket`
- side effect: updates `session.referral_handoff`

Schema:

- `handoff_title: str`
- `referral_reason: str`
- `clinical_summary: str`
- `patient_snapshot: dict`
- `ranked_providers: list`
- `next_steps: list[str]`
- `export_metadata: dict`

Where it plugs into the pipeline:

- File: [agents/orchestrator.jac](/Users/sarthakpatel/CareAnchor/agents/orchestrator.jac)
- Inside `walker :pub export_pdf`
- Build the packet before `build_session_pdf_payload(session)`
- Attach packet to the export payload, for example:

```jac
import from agents.referral_handoff { build_referral_handoff_packet, packet_to_dict }
packet = build_referral_handoff_packet(session);
payload = build_session_pdf_payload(session);
payload["referral_handoff"] = packet_to_dict(packet);
```

PDF exporter seam:

- File: [services/pdf_exporter.jac](/Users/sarthakpatel/CareAnchor/services/pdf_exporter.jac)
- Add `_referral_handoff_section(session: UserSession) -> str`
- Render it after `Provider Recommendations` and before `Risk & Safety Flags`

Why this seam is correct:

- It fits the existing export flow exactly
- It reuses summary, diagnosis, risk, and provider state already present on `UserSession`
- It avoids re-running earlier agents during PDF generation

Jac scaffold:

- File: [agents/referral_handoff.jac](/Users/sarthakpatel/CareAnchor/agents/referral_handoff.jac)
- Main entrypoints:
  - `build_referral_handoff_packet(session)`
  - `packet_to_dict(packet)`

## Shared Model Hooks

Added to [models/session.jac](/Users/sarthakpatel/CareAnchor/models/session.jac):

- `RankedProvider`
- `ReferralHandoffPacket`
- `UserSession.ranked_provider_options`
- `UserSession.referral_handoff`

These give the two agents stable storage and API-visible output contracts.

## Implementation Order

1. Wire `Provider Ranking Agent` into [agents/diagnosis.jac](/Users/sarthakpatel/CareAnchor/agents/diagnosis.jac).
2. Update [agents/messaging.jac](/Users/sarthakpatel/CareAnchor/agents/messaging.jac) to prefer ranked providers when present.
3. Wire `Referral Handoff Agent` into [agents/orchestrator.jac](/Users/sarthakpatel/CareAnchor/agents/orchestrator.jac) `export_pdf`.
4. Extend [services/pdf_exporter.jac](/Users/sarthakpatel/CareAnchor/services/pdf_exporter.jac) with a referral handoff section.
5. Optionally add `export_json` support so the handoff packet is preserved in JSON exports too.

## Minimal Next Patch

If you want the next implementation pass to stay narrow, make only these live-code changes:

1. In [agents/diagnosis.jac](/Users/sarthakpatel/CareAnchor/agents/diagnosis.jac), call `apply_provider_ranking`.
2. In [agents/orchestrator.jac](/Users/sarthakpatel/CareAnchor/agents/orchestrator.jac), build and attach the referral packet inside `export_pdf`.
3. In [services/pdf_exporter.jac](/Users/sarthakpatel/CareAnchor/services/pdf_exporter.jac), render `session.referral_handoff` if present.
