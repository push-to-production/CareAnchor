# Care Anchor — New Implementation Scaffold Prompt

## Context

You are scaffolding **Care Anchor**, a full-stack medical triage and care coordination platform built
entirely in Jac using the jaseci client framework. The previous implementation (CareAnchor) is
abandoned. Do not reference it. Start clean.

The product lets a user describe symptoms via web chat or Twilio voice call, receive provisional
ICD-10-CM code candidates, and get matched to healthcare providers filtered by insurance and
location. A safety-first intervention layer intercepts crisis language at every turn.

---

## Authoritative References (read before writing any code)

- Language rules: `AGENTS.md` in this repo (canonical; overrides anything else you think you know)
- Spec: `CARE_Anchor_SPECIFICATION.md`
- Runtime pattern: jaseci client — `jac create --use client`, NOT `--use fullstack`

---

## 1. Bootstrap Commands

```bash
# From the Hackathon directory — create a fresh project
jac create care_Anchor --use client
cd care_Anchor

# Install all deps declared in jac.toml (Python + npm together)
jac install

# Run with hot reload
jac start --dev
```

---

## 2. Final File Structure

```
care_Anchor/
├── main.jac                        # Entry point only — exposes walkers + def:pub app()
├── __init__.jac                    # Package root — re-exports server walkers
├── jac.toml                        # All deps here; never npm install manually
├── AGENTS.md                       # Copy from parent dir; agent reads this every session
│
├── models/
│   ├── __init__.jac
│   ├── session.jac                 # UserSession node, ChatMessage obj, value objs
│   ├── codes.jac                   # DiagnosisCode obj
│   └── provider.jac                # ProviderOption obj
│
├── agents/
│   ├── __init__.jac
│   ├── orchestrator.jac            # Public walkers (API surface) — create_session, process_message
│   ├── conversation.jac            # Symptom/location/insurance extraction via by llm()
│   ├── intervention.jac            # Crisis detection — deterministic first, llm fallback
│   ├── diagnosis.jac               # ICD-10-CM code matching via by llm() + symptom_mapper
│   ├── calling.jac                 # Collects location + insurance before provider search
│   ├── messaging.jac               # Generates final markdown reply with provider results
│   └── summary.jac                 # CareSummary generation + JSON/PDF export walkers
│
├── services/
│   ├── __init__.jac
│   ├── common.jac                  # uuid, iso_now, text helpers — NO llm here
│   ├── symptom_mapper.jac          # Keyword → ICD code rules + by llm() enrichment
│   ├── transcript_parser.jac       # Rule-based field extraction + by llm() merge
│   ├── provider_matcher.jac        # Mock directory search; swap ZocDoc API here later
│   ├── safety_rules.jac            # CRISIS_PHRASES list — deterministic, no llm
│   ├── json_exporter.jac           # Writes exports/*.json
│   └── pdf_exporter.jac            # Writes exports/*.pdf via reportlab
│
├── data/
│   ├── __init__.jac
│   ├── mock_providers.jac          # get_mock_provider_directory() → list[ProviderOption]
│   └── icd_codes.jac               # Subset of ICD-10-CM for demo; full file via JSON load
│
├── components/                     # ALL files here are .cl.jac (client-only)
│   ├── __init__.jac
│   ├── AppShell.cl.jac             # Root layout; calls sv import walkers; owns all state
│   ├── ChatWindow.cl.jac           # Message feed + composer
│   ├── MessageBubble.cl.jac        # Single message row
│   ├── CrisisBanner.cl.jac         # Red safety banner when intervention_active
│   ├── SummaryPanel.cl.jac         # Symptoms / codes / providers sidebar
│   ├── AgentTrace.cl.jac           # Pipeline status pills
│   └── ExportButtons.cl.jac        # JSON / PDF export triggers
│
└── styles/
    └── main.css                    # Plain CSS; import in AppShell.cl.jac
```

---

## 3. jac.toml

```toml
[project]
name = "care_Anchor"
version = "0.1.0"
description = "Care Anchor — AI triage and provider matching"
entry-point = "main.jac"

[dependencies]
python-dotenv = ">=1.0.0"
requests = ">=2.31.0"
reportlab = ">=4.0.0"
twilio = ">=9.0.0"

[dependencies.npm]
react = "^18.2.0"
react-dom = "^18.2.0"
jac-client-node = "1.0.7"

[dependencies.npm.dev]
vite = "^6.4.1"
"@vitejs/plugin-react" = "^4.2.1"
"@jac-client/dev-deps" = "2.0.0"

[dev-dependencies]
watchdog = ">=3.0.0"

[serve]
base_route_app = "app"
port = 8000

[plugins.client]
port = 5173

[plugins.byllm]
model_name = "gpt-4o-mini"
```

---

## 4. main.jac — Entry Point Pattern (DO NOT deviate)

```jac
"""Care Anchor entry point."""

import from dotenv { load_dotenv }
import from os { getenv }

glob _: bool = load_dotenv() or True;

# Lift server walkers into __main__ scope so .cl.jac files can reach them
# via: sv import from __main__ { create_session, process_message, ... }
import from .agents.orchestrator {
    create_session,
    process_message,
    get_session,
    export_json,
    export_pdf,
    load_demo
}

# Client entry — import AppShell from its .cl.jac file
cl import from .components.AppShell { AppShell }

cl {
    def:pub app() -> JsxElement {
        return <AppShell />;
    }
}
```

**Rules:**
- `import from .agents.orchestrator { ... }` is a plain import (server scope). This is what
  makes those walkers reachable as `sv import from __main__` inside `.cl.jac` files.
- `cl import from .components.AppShell { AppShell }` imports a client component.
- `def:pub app() -> JsxElement` is the Vite entry point. Return type must be `JsxElement`,
  not `any`.
- Do NOT add nodes, walkers, or business logic to `main.jac`. It is a wiring file only.

---

## 5. __init__.jac — Package Root

```jac
"""Care Anchor package."""

import from .agents.orchestrator {
    create_session,
    process_message,
    get_session,
    export_json,
    export_pdf,
    load_demo
}
```

Use full dotted paths in `__init__.jac`. Never use bare `include nodes;`.

---

## 6. models/session.jac — Graph Model

```jac
"""Session graph node and supporting value objects."""

import from .codes { DiagnosisCode }
import from .provider { ProviderOption }
import from ..services.common { APP_DISCLAIMER, iso_now }

obj ChatMessage {
    has role: str;
    has content: str;
    has timestamp: str;
    has agent: str;
}

obj CareSummary {
    has symptom_codes: list[DiagnosisCode];
    has provider_options: list[ProviderOption];
    has summary: str;
    has location: str;
    has insurance: str;
    has risk_flags: list[str];
    has agent_path: list[str];
    has transcript_excerpt: str;
}

obj ConversationStateUpdate {
    has extracted_symptoms: list[str];
    has follow_up_question: str;
    has enough_for_diagnosis: bool;
    has location: str | None = None;
    has insurance: str | None = None;
    has duration: str | None = None;
    has severity: str | None = None;
}

obj InterventionDecision {
    has is_crisis: bool;
    has reason: str;
    has urgency: str;
    has response_markdown: str;
    has can_resume_if_user_declines: bool;
}

obj DiagnosisResult {
    has symptom_codes: list[DiagnosisCode];
    has inferred_specialties: list[str];
    has provider_query_terms: list[str];
    has narrative_reasoning: str;
    has confidence_note: str;
}

obj CallingPreparation {
    has normalized_location: str;
    has normalized_insurance: str;
    has provider_search_ready: bool;
    has missing_fields: list[str];
    has note: str;
}

node UserSession {
    has session_id: str;
    has created_at: str;
    has updated_at: str;
    has transcript: list[ChatMessage] = [];
    has extracted_symptoms: list[str] = [];
    has risk_flags: list[str] = [];
    has assigned_codes: list[DiagnosisCode] = [];
    has provider_options: list[ProviderOption] = [];
    has active_agent: str = "Conversation Agent";
    has agent_path: list[str] = [];
    has intervention_active: bool = False;
    has intervention_resolved: bool = False;
    has last_user_message: str = "";
    has symptom_duration: str | None = None;
    has severity: str | None = None;
    has location: str | None = None;
    has insurance: str | None = None;
    has summary_text: str | None = None;
}
```

**Graph rule:** `root ++> UserSession(...)` persists the session automatically. All `commit()`
calls happen in orchestrator walkers only — never inside agents or services.

---

## 7. agents/orchestrator.jac — Public Walker Surface

```jac
"""Public walkers — these become POST /walker/<Name> endpoints."""

import from ..models.session {
    UserSession, append_message, session_to_dict, update_session_timestamp
}
import from ..services.common { new_session_id, iso_now }
import from .conversation { minimum_fields_ready, run_conversation_agent }
import from .intervention { run_intervention_agent, try_resume_from_intervention }
import from .calling { run_calling_agent, build_calling_follow_up }
import from .diagnosis { run_diagnosis_agent }
import from .messaging { run_messaging_agent }
import from .summary { run_summary_agent, export_summary_json_payload, export_summary_pdf_payload }

def find_session(sid: str) -> UserSession | None {
    sessions = [-->](?:UserSession, session_id == sid);
    if sessions { return sessions[0]; }
    return None;
}

def build_payload(session: UserSession, reply: str, crisis: bool = False) -> dict {
    return {
        "session_id": session.session_id,
        "reply_markdown": reply,
        "session": session_to_dict(session),
        "crisis": crisis
    };
}

def run_pipeline(session: UserSession, message: str) -> dict {
    append_message(session, "user", message, "User");
    session.last_user_message = message;
    update_session_timestamp(session);

    intervention = run_intervention_agent(session, message);
    if intervention["triggered"] {
        reply = intervention["decision"].response_markdown;
        append_message(session, "assistant", reply, "Intervention Agent");
        return build_payload(session, reply, True);
    }

    resumed = try_resume_from_intervention(session, message);
    if resumed != None {
        append_message(session, "assistant", resumed, "Conversation Agent");
        return build_payload(session, resumed);
    }

    if session.intervention_active {
        hold = "**Safety check** — Are you safe right now? If in immediate danger call **911** or text **988**.";
        append_message(session, "assistant", hold, "Intervention Agent");
        return build_payload(session, hold, True);
    }

    run_conversation_agent(session, message);
    calling = run_calling_agent(session);

    if not minimum_fields_ready(session) or not calling.provider_search_ready {
        reply = build_calling_follow_up(session, calling);
        append_message(session, "assistant", reply, "Calling Agent");
        return build_payload(session, reply);
    }

    diagnosis = run_diagnosis_agent(session);
    summary = run_summary_agent(session);
    reply = run_messaging_agent(session, diagnosis, summary);
    append_message(session, "assistant", reply, "Messaging Agent");
    return build_payload(session, reply);
}

walker:pub create_session {
    can start with Root entry {
        sid = new_session_id();
        now = iso_now();
        created = root ++> UserSession(session_id=sid, created_at=now, updated_at=now);
        session = created[0];
        session.active_agent = "Conversation Agent";
        session.agent_path = ["Conversation Agent:active"];
        welcome = "Hi, I'm Care Anchor. Tell me your symptoms, plus your city/state and insurance when you can.";
        append_message(session, "assistant", welcome, "Conversation Agent");
        session.agent_path.append("Conversation Agent:completed");
        commit();
        report build_payload(session, welcome);
    }
}

walker:pub process_message {
    has session_id: str;
    has message: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found", "session_id": self.session_id};
            disengage;
        }
        payload = run_pipeline(session, self.message);
        commit();
        report payload;
    }
}

walker:pub get_session {
    has session_id: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found"};
            disengage;
        }
        report {"session_id": session.session_id, "session": session_to_dict(session)};
    }
}

walker:pub export_json {
    has session_id: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found"};
            disengage;
        }
        payload = export_summary_json_payload(session);
        commit();
        report payload;
    }
}

walker:pub export_pdf {
    has session_id: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found"};
            disengage;
        }
        payload = export_summary_pdf_payload(session);
        commit();
        report payload;
    }
}

walker:pub load_demo {
    has case_id: int = 1;

    can start with Root entry {
        sid = new_session_id();
        now = iso_now();
        created = root ++> UserSession(session_id=sid, created_at=now, updated_at=now);
        session = created[0];
        messages = [
            "I've been dizzy for two days and I missed one of my blood pressure pills. I'm in Austin, TX and have Aetna.",
            "I've had nausea and stomach pain since yesterday evening. I'm in Denver, CO with Blue Cross.",
            "I feel like I want to die. Nothing is worth it anymore."
        ];
        msg = messages[0];
        if self.case_id == 2 { msg = messages[1]; }
        elif self.case_id == 3 { msg = messages[2]; }
        payload = run_pipeline(session, msg);
        commit();
        report payload;
    }
}
```

**Walker rules:**
- All public walkers use `walker:pub` (space before colon, not `walker :pub`). Check AGENTS.md —
  both `walker:pub` and `walker :pub` are valid; match the style already in the file.
- `has session_id: str;` with no default = required POST body field.
- `has case_id: int = 1;` with default = optional POST body field.
- ALL graph mutations (`++>`, `commit()`) happen here, not in agents or services.
- `report` appends to `.reports`. Client reads `result.reports[0]`.

---

## 8. services/safety_rules.jac — Deterministic Crisis Detection

```jac
"""Crisis phrase matching — no LLM, no network, always fast."""

import from ..models.session { InterventionDecision }
import from .common { normalize_text }

glob CRISIS_PHRASES: list[str] = [
    "i want to kill myself", "i want to die", "im suicidal", "i m suicidal",
    "i want to hurt myself", "i dont want to live anymore", "i do not want to live anymore",
    "i want to end it", "i might hurt myself", "i feel like i want to die",
    "nothing is worth it anymore"
];

glob RESUME_PHRASES: list[str] = [
    "no im good", "no i m good", "i m okay", "im okay", "i m safe", "im safe",
    "i m fine now", "im fine now", "no thanks", "i dont need help", "i do not need help"
];

def detect_crisis(message: str) -> InterventionDecision {
    normalized = normalize_text(message);
    for phrase in CRISIS_PHRASES {
        if phrase in normalized {
            return InterventionDecision(
                is_crisis=True,
                reason="self-harm or suicidal language detected",
                urgency="high",
                response_markdown="**Immediate support**\n\nI'm sorry you're going through this. If you're in immediate danger, call **911** or go to the nearest emergency room. In the U.S., call or text **988** right now for the Suicide & Crisis Lifeline.\n\nAre you in immediate danger?",
                can_resume_if_user_declines=True
            );
        }
    }
    return InterventionDecision(
        is_crisis=False,
        reason="no crisis phrases detected",
        urgency="routine",
        response_markdown="",
        can_resume_if_user_declines=True
    );
}

def detect_resume(message: str) -> bool {
    normalized = normalize_text(message);
    for phrase in RESUME_PHRASES {
        if phrase in normalized { return True; }
    }
    return False;
}
```

**Safety rule:** crisis detection MUST be deterministic keyword matching as the primary check.
`by llm()` MAY be used as a secondary enrichment pass but must never replace the phrase list.

---

## 9. services/transcript_parser.jac — LLM Extraction

```jac
"""Structured field extraction from free-text messages."""

import re;
import from os { getenv }
import from ..models.session { ConversationStateUpdate }
import from .common { first_non_empty, merge_strings, normalize_text }
import from .symptom_mapper { extract_symptom_keywords }

glob LLM_READY: bool = (getenv("OPENAI_API_KEY") or "") != "";

glob INSURANCE_ALIASES: dict[str, list[str]] = {
    "Aetna": ["aetna"],
    "Blue Cross Blue Shield": ["blue cross", "blue shield", "bcbs"],
    "Cigna": ["cigna"],
    "UnitedHealthcare": ["unitedhealthcare", "united healthcare", "uhc"],
    "Humana": ["humana"],
    "Medicare": ["medicare"],
    "Medicaid": ["medicaid"]
};

"""Extract structured care coordination fields from the user message.
Never diagnose. Collect: symptoms, location (city/state or zip), insurance, duration, severity.
Return a ConversationStateUpdate with a concise follow_up_question."""
def llm_extract_fields(
    message: str,
    transcript_excerpt: str,
    known_symptoms: list[str],
    known_location: str,
    known_insurance: str
) -> ConversationStateUpdate by llm();
```

**`by llm()` rules:**
- The docstring immediately before the `def` is the LLM system prompt. Write it carefully.
- Return type must be a concrete `obj` or primitive — the runtime serializes it automatically.
- Wrap every `by llm()` call in `try { } except Exception as e { }` and fall back to the
  rule-based result.
- Gate on `LLM_READY` so the app works without an API key (rule-based fallback).

---

## 10. components/AppShell.cl.jac — Root Client Component

```jac
"""Root application shell. Owns all session state."""

import "../styles/main.css";

cl import from react { useEffect }
sv import from __main__ {
    create_session,
    process_message,
    export_json,
    export_pdf,
    load_demo
}

import from .AgentTrace { AgentTrace }
import from .ChatWindow { ChatWindow }
import from .CrisisBanner { CrisisBanner }
import from .ExportButtons { ExportButtons }
import from .SummaryPanel { SummaryPanel }

def emptySession() -> dict {
    return {
        "transcript": [],
        "extracted_symptoms": [],
        "risk_flags": [],
        "assigned_codes": [],
        "provider_options": [],
        "active_agent": "Conversation Agent",
        "agent_trace": [
            {"name": "Intervention Agent", "status": "listening"},
            {"name": "Conversation Agent", "status": "idle"},
            {"name": "Calling Agent", "status": "idle"},
            {"name": "Diagnosis Agent", "status": "idle"},
            {"name": "Messaging Agent", "status": "idle"},
            {"name": "Summary Agent", "status": "idle"}
        ],
        "intervention_active": False,
        "intervention_resolved": False,
        "location": None,
        "insurance": None,
        "summary_text": None,
        "disclaimer": "Care Anchor supports care coordination. It does not replace emergency care or professional diagnosis."
    };
}

def:pub AppShell() -> JsxElement {
    has sessionId: str = "";
    has session: dict = emptySession();
    has draft: str = "";
    has sending: bool = False;
    has booting: bool = True;
    has exportStatus: str = "";
    has errorText: str = "";

    async def bootstrap() -> None {
        booting = True;
        errorText = "";
        exportStatus = "";
        result = root spawn create_session();
        if result.reports.length > 0 {
            payload = result.reports[0];
            sessionId = payload["session_id"];
            session = payload["session"];
        } else {
            errorText = "Unable to start a Care Anchor session.";
        }
        draft = "";
        booting = False;
    }

    async def sendMessage() -> None {
        if sending or booting or draft.trim() == "" or sessionId == "" { return; }
        sending = True;
        errorText = "";
        outbound = draft;
        draft = "";
        result = root spawn process_message(session_id=sessionId, message=outbound);
        if result.reports.length > 0 {
            payload = result.reports[0];
            if payload["session"] { session = payload["session"]; }
        } else {
            errorText = "The message could not be processed.";
        }
        sending = False;
    }

    async def runDemo(caseId: int) -> None {
        sending = True;
        errorText = "";
        exportStatus = "";
        result = root spawn load_demo(case_id=caseId);
        if result.reports.length > 0 {
            payload = result.reports[0];
            sessionId = payload["session_id"];
            session = payload["session"];
            draft = "";
        } else {
            errorText = "Demo case could not be loaded.";
        }
        sending = False;
        booting = False;
    }

    async def doExportJson() -> None {
        if sessionId == "" { return; }
        result = root spawn export_json(session_id=sessionId);
        if result.reports.length > 0 {
            payload = result.reports[0];
            exportStatus = "JSON saved to " + payload["file_path"];
        }
    }

    async def doExportPdf() -> None {
        if sessionId == "" { return; }
        result = root spawn export_pdf(session_id=sessionId);
        if result.reports.length > 0 {
            payload = result.reports[0];
            exportStatus = "PDF saved to " + payload["file_path"];
        }
    }

    useEffect(lambda -> None { bootstrap(); }, []);

    return <div className="app-shell">
        <header className="hero">
            <div className="brand">Care Anchor</div>
            <p className="hero-copy">{session["disclaimer"]}</p>
        </header>

        <CrisisBanner active={session["intervention_active"]} riskFlags={session["risk_flags"]} />

        {errorText != "" and <div className="error-banner">{errorText}</div>}

        <main className="workspace">
            <div className="workspace__main">
                <ChatWindow
                    transcript={session["transcript"]}
                    draft={draft}
                    sending={sending or booting}
                    activeAgent={session["active_agent"]}
                    onDraftChange={lambda value: any -> None { draft = value; }}
                    onSend={lambda -> None { sendMessage(); }}
                    onDemo={lambda caseId: any -> None { runDemo(caseId); }}
                    onReset={lambda -> None { bootstrap(); }}
                />
            </div>
            <aside className="workspace__side">
                <SummaryPanel session={session} />
                <AgentTrace trace={session["agent_trace"]} />
                <ExportButtons
                    sessionId={sessionId}
                    onJson={lambda -> None { doExportJson(); }}
                    onPdf={lambda -> None { doExportPdf(); }}
                    exportStatus={exportStatus}
                />
            </aside>
        </main>
    </div>;
}
```

**.cl.jac rules (enforced by AGENTS.md):**
- `sv import from __main__ { ... }` at top level (outside any function). These become
  `POST /walker/<Name>` calls at runtime — the jaseci compiler wires this automatically.
- `root spawn WalkerName(field=value)` in `async def` functions. The function MUST be `async`.
- `result.reports.length` not `len(result.reports)` — you are in JS context.
- `.trim()` not `.strip()`. `String(x)` not `str(x)`. No f-strings — use `"text " + var`.
- `has` fields inside a `def:pub` component become React `useState`. Mutate directly; the
  compiler handles state updates.
- `useEffect(lambda -> None { bootstrap(); }, []);` — the correct lifecycle pattern. Do NOT
  use `async can with entry`.
- Event handlers: `onClick={lambda e: any -> None { fn(); }}` — body must have at least one
  statement. Empty body: `lambda e: any -> None { 0; }`.
- `className` not `class` in JSX.

---

## 11. Data Flow Summary

```
POST /walker/create_session
  → orchestrator.create_session walker
  → root ++> UserSession(...)
  → reports { session_id, reply_markdown, session: dict }

POST /walker/process_message  { session_id, message }
  → orchestrator.process_message walker
  → run_pipeline()
      1. intervention agent  (keyword safety check — always first)
      2. conversation agent  (extract symptoms, location, insurance via rule + llm)
      3. calling agent       (verify enough fields for provider search)
      4. diagnosis agent     (ICD-10-CM codes via symptom_mapper + llm)
      5. messaging agent     (format final reply with codes + providers)
      6. summary agent       (update summary_text on session)
  → commit()
  → reports { session_id, reply_markdown, session: dict, crisis: bool }

POST /walker/export_json  { session_id }
  → reports { file_path }

POST /walker/export_pdf   { session_id }
  → reports { file_path }

POST /walker/load_demo    { case_id: 1|2|3 }
  → same shape as process_message response
```

---

## 12. `by llm()` Placement Rules

| Location | Allowed? | Notes |
|---|---|---|
| `services/transcript_parser.jac` | Yes | Extract conversation fields |
| `services/symptom_mapper.jac` | Yes | Map symptoms to ICD codes |
| `agents/summary.jac` | Yes | Generate narrative summary |
| `agents/messaging.jac` | Yes | Format final reply markdown |
| `services/safety_rules.jac` | **No** | Crisis detection must be deterministic |
| `agents/orchestrator.jac` | **No** | Walkers only orchestrate; no llm directly |
| Any `.cl.jac` file | **No** | Client-side; all llm calls go through walkers |

Every `by llm()` function must:
1. Have a docstring immediately above it (this becomes the system prompt).
2. Return a typed value — an `obj`, a primitive, or `list[obj]`.
3. Be called inside a `try { } except Exception as e { fallback; }` block.
4. Be gated on `LLM_READY` or similar env-var check so the app degrades gracefully.

---

## 13. Common Errors to Avoid (from AGENTS.md)

```
WRONG  walker:pub MyWalker { has x: list; }     # list without default = required POST field
RIGHT  walker:pub MyWalker { has x: list = []; }

WRONG  cl import from .agents.orchestrator { create_session }  # walkers are server-side
RIGHT  sv import from __main__ { create_session }              # inside .cl.jac files

WRONG  def:pub app() -> any                     # conflicts with builtin
RIGHT  def:pub app() -> JsxElement

WRONG  !x                                       # JS bang does not exist in Jac
RIGHT  not x

WRONG  len(items) in .cl.jac                   # server builtin
RIGHT  items.length

WRONG  f"Hello {name}" in .cl.jac              # no f-strings client-side
RIGHT  "Hello " + name

WRONG  true / false                             # FAILS at runtime even if syntax passes
RIGHT  True / False

WRONG  obj = json.loads(s)                      # obj is a reserved keyword
RIGHT  data = json.loads(s)

WRONG  a ++> Edge() ++> b
RIGHT  a +>: Edge() :+> b

WRONG  [-->:E:]
RIGHT  [->:E:->]

WRONG  case 1 { stmt; }
RIGHT  case 1: stmt;

WRONG  case "x": { stmt; }
RIGHT  case "x": if True { stmt; }

WRONG  print("x");   at module top level
RIGHT  with entry { print("x"); }

WRONG  lambda e: any -> None {}
RIGHT  lambda e: any -> None { 0; }

WRONG  jac create --use fullstack
RIGHT  jac create --use client

WRONG  npm install inside .jac/client/
RIGHT  jac add --npm pkgname   (or edit jac.toml then jac install)

WRONG  GET /walker/Name  to execute a walker
RIGHT  POST /walker/Name

WRONG  has x: str | None = None  in walker (pydantic 422 risk)
RIGHT  has x: str = ""  with empty string sentinel
```

---

## 14. Implementation Order

Build in this sequence. Each step must pass `jac check` before moving on.

1. **jac.toml + .env** — deps and env vars
2. **models/** — `codes.jac`, `provider.jac`, `session.jac` — no logic, just data shapes
3. **services/common.jac** — uuid, iso_now, text helpers
4. **data/mock_providers.jac** — hard-coded list of ~10 providers for demo
5. **services/safety_rules.jac** — CRISIS_PHRASES list, `detect_crisis()`, `detect_resume()`
6. **services/symptom_mapper.jac** — keyword rules first, `by llm()` enrichment second
7. **services/transcript_parser.jac** — rule-based extraction + `llm_extract_fields by llm()`
8. **services/provider_matcher.jac** — filter mock directory by specialty + insurance
9. **agents/intervention.jac** — wraps `safety_rules.detect_crisis()`
10. **agents/conversation.jac** — wraps `transcript_parser.build_conversation_state_update()`
11. **agents/calling.jac** — checks location + insurance completeness, builds follow-up prompt
12. **agents/diagnosis.jac** — wraps `symptom_mapper.build_diagnosis_result()` + provider match
13. **agents/messaging.jac** — formats final markdown reply from diagnosis + summary
14. **agents/summary.jac** — generates CareSummary + export wrappers
15. **agents/orchestrator.jac** — wires pipeline, defines public walkers, calls `commit()`
16. **main.jac** + **__init__.jac** — import orchestrator walkers, define `def:pub app()`
17. **components/CrisisBanner.cl.jac** — simplest component, no state
18. **components/MessageBubble.cl.jac** — renders a single chat message
19. **components/AgentTrace.cl.jac** — status pills from `session["agent_trace"]`
20. **components/ExportButtons.cl.jac** — two buttons, `sv import` export walkers
21. **components/ProviderCard.cl.jac** — renders one provider option
22. **components/SummaryPanel.cl.jac** — symptoms, codes, providers, summary text
23. **components/ChatWindow.cl.jac** — message feed + composer + demo buttons
24. **components/AppShell.cl.jac** — root component, all state, bootstrap logic
25. **styles/main.css** — layout, typography, crisis styles
26. **services/json_exporter.jac** + **services/pdf_exporter.jac** — file writes
27. **Demo smoke-test** — run all three demo cases; verify intervention fires on case 3

---

## 15. Environment Variables (.env)

```
OPENAI_API_KEY=sk-...
JAC_SECRET_KEY=change_me_in_production
TWILIO_ACCOUNT_SID=AC...
TWILIO_AUTH_TOKEN=...
```

Load in `main.jac`:
```jac
import from dotenv { load_dotenv }
import from os { getenv }
glob _: bool = load_dotenv() or True;
```

Note: `.env` is **not** auto-loaded by the Jac runtime. The `load_dotenv()` call in `main.jac`
is required.

---

## 16. Running the Project

```bash
# Install everything (Python deps + npm)
jac install

# Dev mode with hot reload
jac start --dev

# Check syntax without running
jac check main.jac

# Backend only (no Vite)
jac start --no-client

# Production
jac start --scale
```

Frontend: `http://localhost:8000`  
API docs: `http://localhost:8001/docs` (jac-scale only)  
Walker endpoints: `POST http://localhost:8001/walker/<Name>`
