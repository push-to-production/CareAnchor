# Care Anchor — Implementation Prompts Part 4
## Orchestrator, Export Services & Entry Point

> **Blueprint phase:** Steps 16–20 of 27  
> **Goal:** Wire the full backend pipeline. Define public walker endpoints, add file exporters,
> and write the entry-point files. After this part the backend should start and serve API requests.  
> **Prerequisite:** Parts 1–3 complete; all agent files pass `jac check`.

---

## Prompt 16 — Orchestrator: Public Walker Surface

````text
You are continuing to build **Care Anchor**. Parts 1–3 are complete.

### Context
`agents/orchestrator.jac` defines the public API surface — all walkers in this file become
`POST /walker/<Name>` endpoints. This is the ONLY file that:
- Calls `commit()` after graph mutations.
- Calls `root ++>` to create nodes.
- Defines `walker:pub` archetypes.

All business logic lives in agents and services. The orchestrator only orchestrates.

Key rules from `AGENTS.md`:
- `walker:pub` or `walker :pub` — both valid; match existing style.
- `has session_id: str;` (no default) = required POST body field.
- `has case_id: int = 1;` (with default) = optional POST body field.
- `report` appends to `.reports`. Client reads `result.reports[0]`.
- `disengage` exits the walker immediately.
- Graph filter: `[-->](?:UserSession, session_id == sid)` — note the space before `?:`.

### File to Create: `agents/orchestrator.jac`

```jac
"""Public walkers — POST /walker/<Name> endpoints."""

import from ..models.session {
    UserSession, append_message, session_to_dict, update_session_timestamp
}
import from ..services.common { new_session_id, iso_now }
import from .conversation { minimum_fields_ready, run_conversation_agent }
import from .intervention { run_intervention_agent, try_resume_from_intervention }
import from .calling { run_calling_agent, build_calling_follow_up }
import from .diagnosis { run_diagnosis_agent }
import from .messaging { run_messaging_agent }
import from .summary { run_summary_agent }

def find_session(sid: str) -> UserSession | None {
    sessions = [-->](?:UserSession, session_id == sid);
    if sessions { return sessions[0]; }
    return None;
}

def build_payload(session: UserSession, reply: str, crisis: bool) -> dict {
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
        decision = intervention["decision"];
        reply = decision.response_markdown;
        append_message(session, "assistant", reply, "Intervention Agent");
        return build_payload(session, reply, True);
    }

    resumed = try_resume_from_intervention(session, message);
    if resumed != None {
        append_message(session, "assistant", resumed, "Conversation Agent");
        return build_payload(session, resumed, False);
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
        return build_payload(session, reply, False);
    }

    diagnosis = run_diagnosis_agent(session);
    summary_text = run_summary_agent(session);
    reply = run_messaging_agent(session, diagnosis, summary_text);
    append_message(session, "assistant", reply, "Messaging Agent");
    return build_payload(session, reply, False);
}

walker :pub create_session {
    can start with Root entry {
        sid = new_session_id();
        now = iso_now();
        created = root ++> UserSession(session_id=sid, created_at=now, updated_at=now);
        session = created[0];
        session.active_agent = "Conversation Agent";
        session.agent_path = ["Conversation Agent:active"];
        welcome = "Hi, I'm Care Anchor. Tell me your symptoms, and when you can, share your city/state and insurance so I can find providers near you.";
        append_message(session, "assistant", welcome, "Conversation Agent");
        session.agent_path.append("Conversation Agent:completed");
        commit();
        report build_payload(session, welcome, False);
    }
}

walker :pub process_message {
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

walker :pub get_session {
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

walker :pub export_json {
    has session_id: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found"};
            disengage;
        }
        import from ..services.json_exporter { write_session_json }
        path = write_session_json(session);
        commit();
        report {"file_path": path, "session_id": self.session_id};
    }
}

walker :pub export_pdf {
    has session_id: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found"};
            disengage;
        }
        import from ..services.pdf_exporter { write_session_pdf }
        path = write_session_pdf(session);
        commit();
        report {"file_path": path, "session_id": self.session_id};
    }
}

walker :pub load_demo {
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

### Verification
Run `jac check agents/orchestrator.jac`. Must pass.
The `find_session` function uses a graph filter from within a walker ability, so it only
works inside a walker context — do not call it from plain functions.
````

---

## Prompt 17 — Export Services: JSON & PDF

````text
You are continuing to build **Care Anchor**. Prompts 1–16 are complete.

### Context
`services/json_exporter.jac` and `services/pdf_exporter.jac` write care summary files to the
`exports/` directory. These are called by the orchestrator's `export_json` and `export_pdf`
walkers.

The PDF exporter uses `reportlab` (declared in `jac.toml`). If `reportlab` is not available,
fall back gracefully and write a plain `.txt` file instead.

### File to Create: `services/json_exporter.jac`

```jac
"""Writes session summary to exports/*.json."""

import json;
import os;
import from ..models.session { UserSession, session_to_dict }
import from .common { iso_now }

def write_session_json(session: UserSession) -> str {
    os.makedirs("exports", exist_ok=True);
    filename = "exports/care_anchor_" + session.session_id[:8] + ".json";
    data = session_to_dict(session);
    data["exported_at"] = iso_now();
    with open(filename, "w") as f {
        f.write(json.dumps(data, indent=2));
    }
    return filename;
}
```

### File to Create: `services/pdf_exporter.jac`

```jac
"""Writes session summary to exports/*.pdf using reportlab."""

import os;
import from ..models.session { UserSession }
import from .common { iso_now, APP_DISCLAIMER }

def write_session_pdf(session: UserSession) -> str {
    os.makedirs("exports", exist_ok=True);
    filename = "exports/care_anchor_" + session.session_id[:8] + ".pdf";

    try {
        import from reportlab.lib.pagesizes { letter }
        import from reportlab.platypus { SimpleDocTemplate, Paragraph, Spacer }
        import from reportlab.lib.styles { getSampleStyleSheet }

        doc = SimpleDocTemplate(filename, pagesize=letter);
        styles = getSampleStyleSheet();
        story: list = [];

        story.append(Paragraph("Care Anchor — Session Summary", styles["Title"]));
        story.append(Spacer(1, 12));
        story.append(Paragraph("Session ID: " + session.session_id, styles["Normal"]));
        story.append(Paragraph("Generated: " + iso_now(), styles["Normal"]));
        story.append(Spacer(1, 12));

        if session.extracted_symptoms {
            story.append(Paragraph("Reported Symptoms", styles["Heading2"]));
            story.append(Paragraph(", ".join(session.extracted_symptoms), styles["Normal"]));
            story.append(Spacer(1, 8));
        }

        if session.assigned_codes {
            story.append(Paragraph("Possible Related Conditions (ICD-10-CM)", styles["Heading2"]));
            for c in session.assigned_codes[:5] {
                story.append(Paragraph(c.code + " — " + c.description, styles["Normal"]));
            }
            story.append(Spacer(1, 8));
        }

        if session.provider_options {
            story.append(Paragraph("Matched Providers", styles["Heading2"]));
            for p in session.provider_options[:4] {
                story.append(Paragraph(p.name + " (" + p.specialty + ") — " + p.phone, styles["Normal"]));
            }
            story.append(Spacer(1, 8));
        }

        if session.summary_text {
            story.append(Paragraph("Summary", styles["Heading2"]));
            story.append(Paragraph(session.summary_text, styles["Normal"]));
            story.append(Spacer(1, 8));
        }

        story.append(Spacer(1, 20));
        story.append(Paragraph(APP_DISCLAIMER, styles["Italic"]));
        doc.build(story);

    } except Exception as e {
        txt_filename = filename.replace(".pdf", ".txt");
        with open(txt_filename, "w") as f {
            lines: list[str] = ["Care Anchor Session Summary", "=" * 40];
            lines.append("Session: " + session.session_id);
            if session.extracted_symptoms {
                lines.append("Symptoms: " + ", ".join(session.extracted_symptoms));
            }
            if session.summary_text {
                lines.append("Summary: " + session.summary_text);
            }
            lines.append(APP_DISCLAIMER);
            f.write("\n".join(lines));
        }
        return txt_filename;
    }

    return filename;
}
```

### Verification
Run `jac check services/json_exporter.jac` and `jac check services/pdf_exporter.jac`. Both must pass.
Update `services/__init__.jac` to include the new exports:
```jac
import from care_anchor.services.json_exporter { write_session_json }
import from care_anchor.services.pdf_exporter { write_session_pdf }
```
````

---

## Prompt 18 — Entry Point: main.jac & __init__.jac

````text
You are continuing to build **Care Anchor**. Prompts 1–17 are complete.

### Context
`main.jac` is the Jac entry point — it is the file passed to `jac start`. It does two things:
1. Loads environment variables.
2. Lifts server walkers into `__main__` scope so `.cl.jac` client components can reach them.

`__init__.jac` is the package root — it re-exports the public walker surface.

**Rules from the scaffold spec:**
- `main.jac` is a wiring file only. No nodes, no walkers, no business logic.
- `import from .agents.orchestrator { ... }` is a plain server-side import.
- `cl import from .components.AppShell { AppShell }` imports the root client component.
- `def:pub app() -> JsxElement` must return `JsxElement` — NOT `any`.

### File to Create: `main.jac`

```jac
"""Care Anchor entry point."""

import from dotenv { load_dotenv }
import from os { getenv }

glob _: bool = load_dotenv() or True;

import from .agents.orchestrator {
    create_session,
    process_message,
    get_session,
    export_json,
    export_pdf,
    load_demo
}

cl import from .components.AppShell { AppShell }

cl {
    def:pub app() -> JsxElement {
        return <AppShell />;
    }
}
```

### File to Create: `__init__.jac`

```jac
"""Care Anchor package root."""

import from care_anchor.agents.orchestrator {
    create_session,
    process_message,
    get_session,
    export_json,
    export_pdf,
    load_demo
}
```

### Note
`AppShell.cl.jac` does not exist yet (Part 5). The `cl import` line will cause a compile
error until Part 5 is complete. To test the backend in isolation before building the UI,
comment out the `cl import` and `cl { }` block temporarily:

```jac
# cl import from .components.AppShell { AppShell }
# cl {
#     def:pub app() -> JsxElement {
#         return <AppShell />;
#     }
# }
```

### Verification (backend only)
With the `cl` block commented out:
```bash
jac check main.jac
jac start --no-client
```
The server should start and register the walker endpoints. Visit:
`http://localhost:8001/docs` (if jac-scale) or test with:
```bash
curl -X POST http://localhost:8001/walker/create_session \
  -H "Content-Type: application/json" -d "{}"
```
Expect a JSON response with `session_id` and `reply_markdown`.
````

---

## Prompt 19 — Backend Smoke Test

````text
You are continuing to build **Care Anchor**. Prompts 1–18 are complete. The backend should
now be running at `http://localhost:8001`.

### Context
Before building the UI, verify the full backend pipeline works correctly for all three demo
cases. This prompt describes the tests to run manually or with curl.

### Test 1: Session creation
```bash
curl -s -X POST http://localhost:8001/walker/create_session \
  -H "Content-Type: application/json" \
  -d "{}" | python3 -m json.tool
```
**Expected:** `ok: true`, `data.reports[0].session_id` is a UUID string,
`data.reports[0].reply_markdown` contains the welcome message.

### Test 2: Demo Case 1 (dizziness + missed BP pill, Austin TX, Aetna)
```bash
curl -s -X POST http://localhost:8001/walker/load_demo \
  -H "Content-Type: application/json" \
  -d '{"case_id": 1}' | python3 -m json.tool
```
**Expected:**
- `data.reports[0].crisis` is `false`.
- `data.reports[0].session.assigned_codes` contains R42 (dizziness) and/or I10 (hypertension).
- `data.reports[0].session.provider_options` contains at least one Cardiology or Internal Medicine provider.
- `data.reports[0].session.location` is `"Austin, Tx"` or similar.

### Test 3: Demo Case 2 (nausea + stomach pain, Denver CO, Blue Cross)
```bash
curl -s -X POST http://localhost:8001/walker/load_demo \
  -H "Content-Type: application/json" \
  -d '{"case_id": 2}' | python3 -m json.tool
```
**Expected:**
- `data.reports[0].crisis` is `false`.
- Session codes include R11.0 (nausea) and/or R10.9 (abdominal pain).
- Providers are in Denver or telehealth.

### Test 4: Demo Case 3 (crisis language — "I feel like I want to die")
```bash
curl -s -X POST http://localhost:8001/walker/load_demo \
  -H "Content-Type: application/json" \
  -d '{"case_id": 3}' | python3 -m json.tool
```
**Expected:**
- `data.reports[0].crisis` is `true`.
- `data.reports[0].reply_markdown` contains "988" (Suicide & Crisis Lifeline).
- `data.reports[0].session.intervention_active` is `true`.
- `data.reports[0].session.risk_flags` is non-empty.

### Test 5: Multi-turn conversation with resume
Using the session ID from a crisis session above, send a follow-up:
```bash
curl -s -X POST http://localhost:8001/walker/process_message \
  -H "Content-Type: application/json" \
  -d '{"session_id": "<ID_FROM_TEST_4>", "message": "I am safe, no thanks"}' | python3 -m json.tool
```
**Expected:** `intervention_active` becomes `false`, the reply resumes the intake flow.

### Fix any failures before proceeding to Part 5 (UI layer).
````

---

## Prompt 20 — Global Styles

````text
You are continuing to build **Care Anchor**. The backend is verified. Now begin the UI layer.

### Context
`styles/main.css` provides the layout, typography, and crisis color tokens imported by
`AppShell.cl.jac`. Write clean, readable CSS — no framework required.

The layout is:
```
┌─────────────────────────────────────┐
│  header.hero  (brand + disclaimer)  │
├─────────────────────────────────────┤
│  CrisisBanner (hidden when safe)    │
├──────────────────┬──────────────────┤
│  .workspace__main│  .workspace__side│
│  (ChatWindow)    │  (SummaryPanel   │
│                  │   AgentTrace     │
│                  │   ExportButtons) │
└──────────────────┴──────────────────┘
```

### File to Create: `styles/main.css`

```css
/* ── Reset & Base ─────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --brand:       #1a7f5a;
  --brand-light: #e8f5f0;
  --crisis:      #c0392b;
  --crisis-bg:   #fdecea;
  --text:        #1c1c1e;
  --muted:       #6b7280;
  --border:      #e5e7eb;
  --surface:     #ffffff;
  --radius:      8px;
  --shadow:      0 1px 3px rgba(0,0,0,.10);
  font-size: 16px;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  background: #f3f4f6;
  color: var(--text);
  min-height: 100vh;
}

/* ── App Shell ───────────────────────────────────────────── */
.app-shell { display: flex; flex-direction: column; min-height: 100vh; }

/* ── Hero Header ────────────────────────────────────────── */
.hero {
  background: var(--brand);
  color: #fff;
  padding: 16px 24px;
  display: flex;
  align-items: center;
  gap: 16px;
}
.brand { font-size: 1.4rem; font-weight: 700; letter-spacing: -.02em; }
.hero-copy { font-size: .8rem; opacity: .85; max-width: 640px; }

/* ── Crisis Banner ───────────────────────────────────────── */
.crisis-banner {
  background: var(--crisis-bg);
  border-left: 4px solid var(--crisis);
  color: var(--crisis);
  padding: 12px 24px;
  font-weight: 600;
  font-size: .9rem;
}
.crisis-banner__flags { font-weight: 400; font-size: .8rem; margin-top: 4px; }

/* ── Error Banner ────────────────────────────────────────── */
.error-banner {
  background: #fff3cd;
  border-left: 4px solid #e6a817;
  padding: 10px 24px;
  font-size: .875rem;
  color: #7a4f00;
}

/* ── Workspace Layout ───────────────────────────────────── */
.workspace {
  display: flex;
  flex: 1;
  gap: 0;
  height: calc(100vh - 68px);
  overflow: hidden;
}
.workspace__main { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
.workspace__side {
  width: 320px;
  min-width: 280px;
  border-left: 1px solid var(--border);
  background: var(--surface);
  overflow-y: auto;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

/* ── Chat Window ─────────────────────────────────────────── */
.chat-window { display: flex; flex-direction: column; flex: 1; overflow: hidden; }
.chat-feed {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.chat-composer {
  border-top: 1px solid var(--border);
  padding: 12px 16px;
  display: flex;
  gap: 8px;
  background: var(--surface);
  align-items: flex-end;
}
.chat-composer textarea {
  flex: 1;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 8px 12px;
  font-size: .9rem;
  resize: none;
  min-height: 40px;
  max-height: 120px;
  font-family: inherit;
}
.chat-composer textarea:focus { outline: none; border-color: var(--brand); }
.demo-bar {
  border-top: 1px solid var(--border);
  background: var(--brand-light);
  padding: 8px 16px;
  display: flex;
  gap: 8px;
  align-items: center;
  font-size: .8rem;
  color: var(--muted);
}

/* ── Message Bubbles ─────────────────────────────────────── */
.bubble { max-width: 80%; display: flex; flex-direction: column; gap: 2px; }
.bubble--user { align-self: flex-end; }
.bubble--assistant { align-self: flex-start; }
.bubble__body {
  padding: 10px 14px;
  border-radius: var(--radius);
  font-size: .9rem;
  line-height: 1.5;
  white-space: pre-wrap;
}
.bubble--user .bubble__body { background: var(--brand); color: #fff; border-bottom-right-radius: 2px; }
.bubble--assistant .bubble__body { background: var(--surface); border: 1px solid var(--border); border-bottom-left-radius: 2px; }
.bubble--crisis .bubble__body { background: var(--crisis-bg); border-color: var(--crisis); color: var(--crisis); }
.bubble__meta { font-size: .7rem; color: var(--muted); padding: 0 4px; }

/* ── Agent Trace ─────────────────────────────────────────── */
.agent-trace { display: flex; flex-direction: column; gap: 6px; }
.agent-trace h3 { font-size: .75rem; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); }
.agent-pill {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 10px;
  border-radius: 20px;
  background: #f9fafb;
  border: 1px solid var(--border);
  font-size: .78rem;
}
.agent-pill__dot {
  width: 8px; height: 8px; border-radius: 50%;
  background: var(--muted);
  flex-shrink: 0;
}
.agent-pill--active .agent-pill__dot { background: var(--brand); animation: pulse 1s infinite; }
.agent-pill--completed .agent-pill__dot { background: #16a34a; }
.agent-pill--error .agent-pill__dot { background: var(--crisis); }
@keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: .4; } }

/* ── Summary Panel ───────────────────────────────────────── */
.summary-panel { display: flex; flex-direction: column; gap: 12px; }
.summary-panel h3 { font-size: .8rem; text-transform: uppercase; letter-spacing: .08em; color: var(--muted); border-bottom: 1px solid var(--border); padding-bottom: 4px; }
.summary-panel__item { font-size: .85rem; color: var(--text); }
.code-tag {
  display: inline-block;
  background: var(--brand-light);
  color: var(--brand);
  border: 1px solid var(--brand);
  border-radius: 4px;
  padding: 2px 7px;
  font-size: .75rem;
  margin: 2px;
}
.provider-card {
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 10px 12px;
  background: #fafafa;
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.provider-card__name { font-weight: 600; font-size: .85rem; }
.provider-card__detail { font-size: .78rem; color: var(--muted); }
.provider-card__badge {
  font-size: .7rem;
  background: #e0f2fe;
  color: #0369a1;
  border-radius: 4px;
  padding: 1px 6px;
  display: inline-block;
}

/* ── Buttons ────────────────────────────────────────────── */
.btn {
  padding: 8px 16px;
  border: none;
  border-radius: var(--radius);
  font-size: .875rem;
  font-weight: 500;
  cursor: pointer;
  transition: opacity .15s;
}
.btn:hover { opacity: .88; }
.btn:disabled { opacity: .45; cursor: not-allowed; }
.btn--primary { background: var(--brand); color: #fff; }
.btn--secondary { background: #f3f4f6; color: var(--text); border: 1px solid var(--border); }
.btn--crisis { background: var(--crisis); color: #fff; }
.btn--sm { padding: 5px 10px; font-size: .8rem; }

/* ── Export Buttons ─────────────────────────────────────── */
.export-buttons { display: flex; flex-direction: column; gap: 8px; }
.export-status { font-size: .78rem; color: var(--muted); margin-top: 4px; }

/* ── Responsive ──────────────────────────────────────────── */
@media (max-width: 768px) {
  .workspace { flex-direction: column; height: auto; }
  .workspace__side { width: 100%; border-left: none; border-top: 1px solid var(--border); }
  .bubble { max-width: 95%; }
}
```

### Verification
This is a plain CSS file — no compilation needed. It will be imported by `AppShell.cl.jac`
in the next part via: `import "../styles/main.css";`
````
