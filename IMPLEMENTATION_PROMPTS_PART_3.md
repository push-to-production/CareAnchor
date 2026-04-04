# Care Anchor — Implementation Prompts Part 3
## Agent Layer

> **Blueprint phase:** Steps 10–15 of 27  
> **Goal:** Build each pipeline agent as a pure function module. Agents wrap services — they do
> NOT call the graph, do NOT call `commit()`, and do NOT define walkers.  
> **Prerequisite:** Parts 1–2 complete; all services pass `jac check`.

---

## Prompt 11 — Intervention Agent

````text
You are continuing to build **Care Anchor**. Parts 1–2 are complete.

### Context
`agents/intervention.jac` is the first stage of the message pipeline.
It wraps `services/safety_rules.detect_crisis()` and handles crisis state transitions on
the `UserSession` node. It updates `session.intervention_active` and `session.risk_flags`
but does NOT call `commit()` — that happens in the orchestrator only.

### File to Create: `agents/intervention.jac`

```jac
"""Intervention agent — crisis detection and state management."""

import from ..models.session { UserSession, InterventionDecision }
import from ..services.safety_rules { detect_crisis, detect_resume }

def run_intervention_agent(session: UserSession, message: str) -> dict {
    decision = detect_crisis(message);
    if decision.is_crisis {
        session.intervention_active = True;
        session.intervention_resolved = False;
        session.active_agent = "Intervention Agent";
        flag = "Crisis language detected: " + decision.reason;
        if flag not in session.risk_flags {
            session.risk_flags.append(flag);
        }
        if "Intervention Agent:active" not in session.agent_path {
            session.agent_path.append("Intervention Agent:active");
        }
        return {"triggered": True, "decision": decision};
    }
    return {"triggered": False, "decision": decision};
}

def try_resume_from_intervention(session: UserSession, message: str) -> str | None {
    if not session.intervention_active { return None; }
    if session.intervention_resolved { return None; }

    if detect_resume(message) {
        session.intervention_active = False;
        session.intervention_resolved = True;
        session.active_agent = "Conversation Agent";
        session.agent_path.append("Intervention Agent:resolved");
        return "I'm glad you're safe. Let's continue — please tell me your symptoms, and your city/state and insurance when you can.";
    }
    return None;
}
```

### Key constraints
- `run_intervention_agent` always returns a dict `{"triggered": bool, "decision": InterventionDecision}`.
- `try_resume_from_intervention` returns a `str` reply when the user signals safety, `None` otherwise.
- No `commit()` call here.
- No `by llm()` here (safety rules are deterministic).

### Verification
Run `jac check agents/intervention.jac`. Must pass.
````

---

## Prompt 12 — Conversation Agent

````text
You are continuing to build **Care Anchor**. Prompts 1–11 are complete.

### Context
`agents/conversation.jac` wraps `services/transcript_parser.build_conversation_state_update()`.
It updates the `UserSession` node with extracted fields and returns a follow-up question
if more information is needed.

This agent runs on every non-crisis message. It must:
- Update `session.extracted_symptoms`, `session.location`, `session.insurance`,
  `session.symptom_duration`, `session.severity`.
- Append its status to `session.agent_path`.
- Never call `commit()`.

### File to Create: `agents/conversation.jac`

```jac
"""Conversation agent — symptom and field extraction."""

import from ..models.session { UserSession, ConversationStateUpdate }
import from ..services.transcript_parser { build_conversation_state_update }

def run_conversation_agent(session: UserSession, message: str) -> ConversationStateUpdate {
    session.active_agent = "Conversation Agent";
    session.agent_path.append("Conversation Agent:active");

    update = build_conversation_state_update(
        message=message,
        transcript_messages=session.transcript,
        known_symptoms=session.extracted_symptoms,
        known_location=session.location,
        known_insurance=session.insurance
    );

    for sym in update.extracted_symptoms {
        if sym not in session.extracted_symptoms {
            session.extracted_symptoms.append(sym);
        }
    }

    if update.location and update.location != "" {
        session.location = update.location;
    }
    if update.insurance and update.insurance != "" {
        session.insurance = update.insurance;
    }
    if update.duration and update.duration != "" {
        session.symptom_duration = update.duration;
    }
    if update.severity and update.severity != "" {
        session.severity = update.severity;
    }

    session.agent_path.append("Conversation Agent:completed");
    return update;
}

def minimum_fields_ready(session: UserSession) -> bool {
    has_symptoms = session.extracted_symptoms.length > 0;
    has_location = session.location != None and session.location != "";
    has_insurance = session.insurance != None and session.insurance != "";
    return has_symptoms and has_location and has_insurance;
}
```

### Verification
Run `jac check agents/conversation.jac`. Must pass.
Note: `minimum_fields_ready` will be imported by `agents/orchestrator.jac` later.
````

---

## Prompt 13 — Calling Agent

````text
You are continuing to build **Care Anchor**. Prompts 1–12 are complete.

### Context
`agents/calling.jac` checks whether the conversation has collected enough information to
perform a provider search. It builds a human-readable follow-up question when fields are missing,
and returns a `CallingPreparation` object.

This agent does NOT search providers — it only gatekeeps the pipeline.

### File to Create: `agents/calling.jac`

```jac
"""Calling agent — verifies readiness for provider search."""

import from ..models.session { UserSession, CallingPreparation }
import from ..services.provider_matcher { normalize_insurance }

def run_calling_agent(session: UserSession) -> CallingPreparation {
    session.agent_path.append("Calling Agent:active");

    loc = session.location if session.location else "";
    ins = session.insurance if session.insurance else "";
    norm_ins = normalize_insurance(ins) if ins != "" else "";
    missing: list[str] = [];

    if not session.extracted_symptoms or session.extracted_symptoms.length == 0 {
        missing.append("symptoms");
    }
    if loc == "" { missing.append("location (city and state)"); }
    if ins == "" { missing.append("insurance provider"); }

    ready = missing.length == 0;

    note = "";
    if not ready {
        note = "Waiting for: " + ", ".join(missing) + ".";
    }

    session.agent_path.append("Calling Agent:completed");

    return CallingPreparation(
        normalized_location=loc,
        normalized_insurance=norm_ins,
        provider_search_ready=ready,
        missing_fields=missing,
        note=note
    );
}

def build_calling_follow_up(session: UserSession, prep: CallingPreparation) -> str {
    if not prep.provider_search_ready {
        if "symptoms" in prep.missing_fields {
            return "To help connect you with care, could you describe your symptoms?";
        }
        if "location (city and state)" in prep.missing_fields and "insurance provider" in prep.missing_fields {
            return "I'd also like your city/state and insurance so I can find providers near you. What are those?";
        }
        if "location (city and state)" in prep.missing_fields {
            return "What city and state are you in? I'll use that to find providers near you.";
        }
        if "insurance provider" in prep.missing_fields {
            return "Which insurance do you have? (e.g., Aetna, Blue Cross, Cigna, UnitedHealthcare, Medicare/Medicaid)";
        }
    }
    return "I have everything I need. Let me look up providers for you.";
}
```

### Verification
Run `jac check agents/calling.jac`. Must pass.
````

---

## Prompt 14 — Diagnosis Agent

````text
You are continuing to build **Care Anchor**. Prompts 1–13 are complete.

### Context
`agents/diagnosis.jac` maps extracted symptoms to ICD-10-CM codes and populates
`session.assigned_codes` and `session.provider_options`.

It wraps two services:
- `symptom_mapper.build_diagnosis_result()` → ICD codes + specialties
- `provider_matcher.find_providers()` → filtered provider list

This agent does NOT call `commit()` or define walkers.

### File to Create: `agents/diagnosis.jac`

```jac
"""Diagnosis agent — ICD-10-CM code matching and provider search."""

import from ..models.session { UserSession, DiagnosisResult }
import from ..services.symptom_mapper { build_diagnosis_result }
import from ..services.provider_matcher { find_providers }
import from ..services.common { transcript_excerpt }

def run_diagnosis_agent(session: UserSession) -> DiagnosisResult {
    session.active_agent = "Diagnosis Agent";
    session.agent_path.append("Diagnosis Agent:active");

    excerpt = transcript_excerpt(session.transcript, 8);
    result = build_diagnosis_result(session.extracted_symptoms, excerpt);

    session.assigned_codes = result.symptom_codes;

    loc = session.location if session.location else "";
    ins = session.insurance if session.insurance else "";

    providers = find_providers(
        diagnosis=result,
        location=loc,
        insurance=ins,
        max_results=4
    );
    session.provider_options = providers;

    session.agent_path.append("Diagnosis Agent:completed");
    return result;
}
```

### Verification
Run `jac check agents/diagnosis.jac`. Must pass.
````

---

## Prompt 15 — Messaging Agent & Summary Agent

````text
You are continuing to build **Care Anchor**. Prompts 1–14 are complete.

### Context
These two agents close the pipeline:
- `agents/messaging.jac` formats the final markdown reply shown to the user.
- `agents/summary.jac` generates the `CareSummary` object and provides export helpers.

Both may use `by llm()` for richer output, gated on `LLM_READY`.

### File to Create: `agents/messaging.jac`

```jac
"""Messaging agent — formats the final user-facing reply."""

import from os { getenv }
import from ..models.session { UserSession, DiagnosisResult, CareSummary }
import from ..models.codes { DiagnosisCode }
import from ..models.provider { ProviderOption }

glob LLM_READY: bool = (getenv("OPENAI_API_KEY") or "") != "";

"""Format a concise, empathetic care coordination reply in Markdown.
Include: a brief summary of what was heard, a section listing the 2–3 most relevant
ICD codes with plain-English descriptions, a section listing up to 3 provider options
with name/specialty/phone/insurance note, and a closing disclaimer that this is not a
medical diagnosis. Use ## headings. Keep total length under 600 words."""
def llm_format_reply(
    symptoms: list[str],
    codes: list[DiagnosisCode],
    providers: list[ProviderOption],
    location: str,
    insurance: str,
    narrative: str
) -> str by llm();

def run_messaging_agent(
    session: UserSession,
    diagnosis: DiagnosisResult,
    summary_text: str
) -> str {
    session.active_agent = "Messaging Agent";
    session.agent_path.append("Messaging Agent:active");

    loc = session.location if session.location else "your area";
    ins = session.insurance if session.insurance else "your insurance";

    if LLM_READY and diagnosis.symptom_codes {
        try {
            reply = llm_format_reply(
                symptoms=session.extracted_symptoms,
                codes=diagnosis.symptom_codes,
                providers=session.provider_options,
                location=loc,
                insurance=ins,
                narrative=diagnosis.narrative_reasoning
            );
            session.agent_path.append("Messaging Agent:completed");
            return reply;
        } except Exception as e {
            0;
        }
    }

    lines: list[str] = [];
    lines.append("## What I heard");
    if session.extracted_symptoms {
        lines.append("You mentioned: **" + ", ".join(session.extracted_symptoms[:5]) + "**.");
    } else {
        lines.append("I wasn't able to identify specific symptoms. Please describe how you're feeling.");
    }

    if diagnosis.symptom_codes {
        lines.append("\n## Possible related conditions");
        lines.append("*(For informational purposes only — not a diagnosis)*");
        for code in diagnosis.symptom_codes[:3] {
            lines.append("- **" + code.code + "** — " + code.description);
        }
    }

    if session.provider_options {
        lines.append("\n## Providers near " + loc + " accepting " + ins);
        for p in session.provider_options[:3] {
            lines.append("- **" + p.name + "** (" + p.specialty + ") · " + p.phone);
            if p.telehealth_available { lines.append("  *Telehealth available*"); }
        }
    } else {
        lines.append("\n*No providers found for your location and insurance. Try calling 211 for local referrals.*");
    }

    lines.append("\n---");
    lines.append("*Care Anchor is a care coordination tool. It does not provide medical advice or diagnoses. In an emergency, call 911.*");

    session.agent_path.append("Messaging Agent:completed");
    return "\n".join(lines);
}
```

### File to Create: `agents/summary.jac`

```jac
"""Summary agent — generates CareSummary and export helpers."""

import from os { getenv }
import from ..models.session { UserSession, CareSummary }
import from ..services.common { transcript_excerpt, APP_DISCLAIMER }

glob LLM_READY: bool = (getenv("OPENAI_API_KEY") or "") != "";

"""Write a 3-sentence plain-English care coordination summary for a patient.
Include: what symptoms were reported, what conditions were identified, and what
next steps were recommended. Do not diagnose. Do not include provider names.
Keep it under 120 words."""
def llm_generate_summary(
    symptoms: list[str],
    codes: list[str],
    specialties: list[str],
    location: str,
    insurance: str
) -> str by llm();

def run_summary_agent(session: UserSession) -> str {
    session.agent_path.append("Summary Agent:active");

    code_labels: list[str] = [];
    for c in session.assigned_codes {
        code_labels.append(c.code + " " + c.description);
    }
    specs: list[str] = [];
    for p in session.provider_options {
        if p.specialty not in specs { specs.append(p.specialty); }
    }

    summary = "";
    if LLM_READY and session.extracted_symptoms {
        try {
            summary = llm_generate_summary(
                symptoms=session.extracted_symptoms,
                codes=code_labels,
                specialties=specs,
                location=session.location if session.location else "",
                insurance=session.insurance if session.insurance else ""
            );
        } except Exception as e {
            0;
        }
    }

    if not summary or summary.strip() == "" {
        parts: list[str] = [];
        if session.extracted_symptoms {
            parts.append("Reported symptoms: " + ", ".join(session.extracted_symptoms[:5]) + ".");
        }
        if code_labels {
            parts.append("Possible conditions: " + ", ".join(code_labels[:3]) + ".");
        }
        if session.provider_options {
            parts.append(str(session.provider_options.length) + " provider(s) matched.");
        }
        summary = " ".join(parts) if parts else "Session summary pending.";
    }

    session.summary_text = summary;
    session.agent_path.append("Summary Agent:completed");
    return summary;
}

def build_care_summary(session: UserSession) -> CareSummary {
    excerpt = transcript_excerpt(session.transcript, 6);
    return CareSummary(
        symptom_codes=session.assigned_codes,
        provider_options=session.provider_options,
        summary=session.summary_text if session.summary_text else "",
        location=session.location if session.location else "",
        insurance=session.insurance if session.insurance else "",
        risk_flags=session.risk_flags,
        agent_path=session.agent_path,
        transcript_excerpt=excerpt
    );
}
```

Update `agents/__init__.jac`:

```jac
"""Care Anchor agents package."""

import from care_anchor.agents.intervention { run_intervention_agent, try_resume_from_intervention }
import from care_anchor.agents.conversation { run_conversation_agent, minimum_fields_ready }
import from care_anchor.agents.calling { run_calling_agent, build_calling_follow_up }
import from care_anchor.agents.diagnosis { run_diagnosis_agent }
import from care_anchor.agents.messaging { run_messaging_agent }
import from care_anchor.agents.summary { run_summary_agent, build_care_summary }
```

### Verification
Run `jac check agents/messaging.jac` and `jac check agents/summary.jac`. Both must pass.
````
