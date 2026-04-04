# Care Anchor — Implementation Prompts Part 6
## Client Components — Stateful Components & Full Integration

> **Blueprint phase:** Steps 26–27 of 27 (final)  
> **Goal:** Build the two stateful components (ChatWindow, AppShell), wire the full client
> into `main.jac`, and run an end-to-end integration smoke test.  
> **Prerequisite:** Parts 1–5 complete; all leaf components pass `jac check`.

---

## Prompt 26 — ChatWindow Component

````text
You are continuing to build **Care Anchor**. Parts 1–5 are complete.

### Context
`components/ChatWindow.cl.jac` renders the scrollable message feed, the text composer,
and the demo case buttons. It receives all state and callbacks from `AppShell` — it has
no async state of its own.

Props:
- `transcript: list` — list of `ChatMessage` dicts.
- `draft: str` — current composer text.
- `sending: bool` — disables the send button while a request is in flight.
- `activeAgent: str` — name of the currently active agent.
- `onDraftChange: any` — callback invoked with new textarea value.
- `onSend: any` — callback to send the current draft.
- `onDemo: any` — callback invoked with case_id (int: 1, 2, or 3).
- `onReset: any` — callback to reset the session.

### File to Create: `components/ChatWindow.cl.jac`

```jac
"""Chat message feed and composer."""

cl import from react { useEffect, useRef }
import from .MessageBubble { MessageBubble }

def:pub ChatWindow(
    transcript: list,
    draft: str,
    sending: bool,
    activeAgent: str,
    onDraftChange: any,
    onSend: any,
    onDemo: any,
    onReset: any
) -> JsxElement {
    endRef = useRef(None);

    useEffect(lambda -> None {
        if endRef.current { endRef.current.scrollIntoView({"behavior": "smooth"}); }
    }, [transcript]);

    def handle_key_down(e: any) -> None {
        if e.key == "Enter" and not e.shiftKey {
            e.preventDefault();
            onSend();
        }
    }

    return <div className="chat-window">
        <div className="chat-feed">
            {[<MessageBubble key={String(i)} msg={msg} /> for (i, msg) in enumerate(transcript)]}
            {sending and
                <div className="bubble bubble--assistant">
                    <div className="bubble__body" style={{"opacity": "0.6", "fontStyle": "italic"}}>
                        {activeAgent + " is thinking..."}
                    </div>
                </div>
            }
            <div ref={endRef}></div>
        </div>

        <div className="chat-composer">
            <textarea
                placeholder="Describe your symptoms, location, and insurance..."
                value={draft}
                onChange={lambda e: any -> None { onDraftChange(e.target.value); }}
                onKeyDown={lambda e: any -> None { handle_key_down(e); }}
                disabled={sending}
                rows={2}
            />
            <button
                className="btn btn--primary"
                onClick={lambda e: any -> None { onSend(); }}
                disabled={sending or draft.trim() == ""}
            >
                Send
            </button>
        </div>

        <div className="demo-bar">
            <span>Demo cases:</span>
            <button className="btn btn--secondary btn--sm" onClick={lambda e: any -> None { onDemo(1); }} disabled={sending}>
                Case 1 (Dizziness)
            </button>
            <button className="btn btn--secondary btn--sm" onClick={lambda e: any -> None { onDemo(2); }} disabled={sending}>
                Case 2 (Nausea)
            </button>
            <button className="btn btn--crisis btn--sm" onClick={lambda e: any -> None { onDemo(3); }} disabled={sending}>
                Case 3 (Crisis)
            </button>
            <button className="btn btn--secondary btn--sm" style={{"marginLeft": "auto"}} onClick={lambda e: any -> None { onReset(); }} disabled={sending}>
                New Session
            </button>
        </div>
    </div>;
}
```

### Key notes
- `useRef` is imported from React to enable auto-scroll to the latest message.
- `useEffect` fires after every `transcript` update and scrolls the feed to the bottom.
- `handle_key_down` submits on Enter (without Shift) for desktop UX.
- The "thinking" bubble shows while `sending` is true.
- The composer textarea is disabled while a request is in flight.

### Verification
`jac check components/ChatWindow.cl.jac` must pass.
````

---

## Prompt 27 — AppShell: Root Component & Full Client Wiring

````text
You are continuing to build **Care Anchor**. Prompt 26 is complete.

### Context
`components/AppShell.cl.jac` is the root React component. It:
1. Owns ALL session state as `has` fields (which become `useState` hooks).
2. Calls `root spawn walker()` to communicate with the backend.
3. Passes state and callbacks down to child components.
4. Handles all async operations (bootstrap, send message, demo, export).

Critical `.cl.jac` rules:
- `sv import from __main__ { ... }` — imports server walkers for client use. MUST be at top level.
- `root spawn WalkerName(field=value)` compiles to `await POST /walker/<Name>`.
- The function containing `root spawn` MUST be `async def`.
- `result.reports.length` not `len(result.reports)`.
- `has` fields inside `def:pub` components become React `useState`. Mutate directly.
- `useEffect(lambda -> None { bootstrap(); }, []);` — correct lifecycle pattern.
- No f-strings. Use `"text " + var`.

### File to Create: `components/AppShell.cl.jac`

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

def empty_session() -> dict {
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
    has session: dict = empty_session();
    has draft: str = "";
    has sending: bool = False;
    has booting: bool = True;
    has exportStatus: str = "";
    has errorText: str = "";

    async def bootstrap() -> None {
        booting = True;
        errorText = "";
        exportStatus = "";
        session = empty_session();
        sessionId = "";
        draft = "";
        try {
            result = root spawn create_session();
            if result.reports.length > 0 {
                payload = result.reports[0];
                sessionId = payload["session_id"];
                session = payload["session"];
            } else {
                errorText = "Unable to start a Care Anchor session. Is the backend running?";
            }
        } except Exception as e {
            errorText = "Connection error. Please check that the backend is running.";
        }
        booting = False;
    }

    async def send_message() -> None {
        if sending or booting or draft.trim() == "" or sessionId == "" { return; }
        sending = True;
        errorText = "";
        outbound = draft;
        draft = "";
        try {
            result = root spawn process_message(session_id=sessionId, message=outbound);
            if result.reports.length > 0 {
                payload = result.reports[0];
                if "session" in payload { session = payload["session"]; }
            } else {
                errorText = "The message could not be processed. Please try again.";
            }
        } except Exception as e {
            errorText = "Network error sending message.";
        }
        sending = False;
    }

    async def run_demo(case_id: int) -> None {
        sending = True;
        booting = False;
        errorText = "";
        exportStatus = "";
        try {
            result = root spawn load_demo(case_id=case_id);
            if result.reports.length > 0 {
                payload = result.reports[0];
                sessionId = payload["session_id"];
                session = payload["session"];
                draft = "";
            } else {
                errorText = "Demo case could not be loaded.";
            }
        } except Exception as e {
            errorText = "Error loading demo case.";
        }
        sending = False;
    }

    async def do_export_json() -> None {
        if sessionId == "" { return; }
        exportStatus = "Exporting...";
        try {
            result = root spawn export_json(session_id=sessionId);
            if result.reports.length > 0 {
                payload = result.reports[0];
                exportStatus = "JSON saved: " + payload["file_path"];
            }
        } except Exception as e {
            exportStatus = "JSON export failed.";
        }
    }

    async def do_export_pdf() -> None {
        if sessionId == "" { return; }
        exportStatus = "Exporting...";
        try {
            result = root spawn export_pdf(session_id=sessionId);
            if result.reports.length > 0 {
                payload = result.reports[0];
                exportStatus = "PDF saved: " + payload["file_path"];
            }
        } except Exception as e {
            exportStatus = "PDF export failed.";
        }
    }

    useEffect(lambda -> None { bootstrap(); }, []);

    active_agent = session["active_agent"] if "active_agent" in session else "Conversation Agent";
    intervention_active = session["intervention_active"] if "intervention_active" in session else False;
    risk_flags = session["risk_flags"] if "risk_flags" in session else [];
    agent_trace = session["agent_trace"] if "agent_trace" in session else [];
    disclaimer = session["disclaimer"] if "disclaimer" in session else "Care Anchor — AI triage and care coordination.";

    return <div className="app-shell">
        <header className="hero">
            <div className="brand">Care Anchor</div>
            <p className="hero-copy">{disclaimer}</p>
        </header>

        <CrisisBanner active={intervention_active} riskFlags={risk_flags} />

        {errorText != "" and
            <div className="error-banner">{errorText}</div>
        }

        <main className="workspace">
            <div className="workspace__main">
                <ChatWindow
                    transcript={session["transcript"] if "transcript" in session else []}
                    draft={draft}
                    sending={sending or booting}
                    activeAgent={active_agent}
                    onDraftChange={lambda value: any -> None { draft = value; }}
                    onSend={lambda -> None { send_message(); }}
                    onDemo={lambda case_id: any -> None { run_demo(case_id); }}
                    onReset={lambda -> None { bootstrap(); }}
                />
            </div>
            <aside className="workspace__side">
                <SummaryPanel session={session} />
                <AgentTrace trace={agent_trace} />
                <ExportButtons
                    sessionId={sessionId}
                    onJson={lambda -> None { do_export_json(); }}
                    onPdf={lambda -> None { do_export_pdf(); }}
                    exportStatus={exportStatus}
                />
            </aside>
        </main>
    </div>;
}
```

### Restore main.jac client block
Now that `AppShell.cl.jac` exists, remove the comments from `main.jac`:

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

### Verification
```bash
jac check components/AppShell.cl.jac
jac check main.jac
```
Both must pass.
````

---

## Prompt 28 — Full Integration Smoke Test

````text
You are continuing to build **Care Anchor**. Prompts 1–27 are complete.

### Context
Run the complete application (frontend + backend) and verify all three demo scenarios
end-to-end in the browser.

### Start the dev server
```bash
jac start --dev
```
- Frontend: http://localhost:8000
- Backend API: http://localhost:8001

Watch for any compile errors in the terminal. Fix any Jac syntax errors before proceeding.

### Browser Test Checklist

#### 1. Initial load
- [ ] Page loads without console errors.
- [ ] Welcome message appears in the chat feed.
- [ ] Agent trace shows "Conversation Agent: idle".
- [ ] Summary panel shows the empty state message.
- [ ] CrisisBanner is NOT visible.

#### 2. Manual message — missing fields
Type "I have a headache" and send.
- [ ] Reply asks for location or insurance.
- [ ] Agent trace shows Calling Agent activity.
- [ ] No ICD codes appear yet (not enough info).

#### 3. Manual message — complete fields
Continue with "I'm in Austin, TX and I have Aetna."
- [ ] ICD codes appear in the Summary Panel.
- [ ] At least one provider card appears.
- [ ] Reply contains ## headings and provider info.

#### 4. Demo Case 1 — Dizziness + missed BP pill (Austin, Aetna)
Click "Case 1 (Dizziness)" button.
- [ ] Session resets; new session ID.
- [ ] ICD codes include R42 (dizziness) and/or I10 (hypertension).
- [ ] Provider options include Cardiology or Internal Medicine in Austin.
- [ ] CrisisBanner is NOT shown.

#### 5. Demo Case 2 — Nausea + stomach pain (Denver, Blue Cross)
Click "Case 2 (Nausea)".
- [ ] ICD codes include R11.0 (nausea) and/or R10.9 (abdominal pain).
- [ ] Provider options in Denver or telehealth.
- [ ] Insurance shown as "Blue Cross Blue Shield" in summary.

#### 6. Demo Case 3 — Crisis language
Click "Case 3 (Crisis)".
- [ ] **CrisisBanner IS shown** (red banner at top).
- [ ] Reply contains "988" and "911".
- [ ] `intervention_active` is true (check agent trace pill).
- [ ] No ICD codes shown (pipeline short-circuits at intervention).

#### 7. Crisis resolution
After Case 3, type "I am safe, no thanks" and send.
- [ ] CrisisBanner disappears.
- [ ] Reply invites the user to continue describing symptoms.
- [ ] `intervention_active` is false.

#### 8. Export
After a complete Case 1 session:
- [ ] Click "Export JSON" → status shows file path `exports/care_anchor_*.json`.
- [ ] Click "Export PDF" → status shows file path `exports/care_anchor_*.pdf`.
- [ ] Files exist on disk in the `exports/` directory.

#### 9. New Session
Click "New Session":
- [ ] Chat feed clears.
- [ ] Summary panel resets.
- [ ] A new session ID is generated.

### Common issues and fixes
| Symptom | Likely cause | Fix |
|---|---|---|
| Blank page | `AppShell` compile error | Run `jac check components/AppShell.cl.jac` |
| 422 from walker | Required field missing | Check walker `has` fields have defaults if optional |
| `reports` empty | Walker didn't call `report` | Check orchestrator's `run_pipeline` returns a value |
| Crisis not firing | normalize_text strips quote | Verify `detect_crisis` test with "i feel like i want to die" |
| No providers | Insurance mismatch | Check `normalize_insurance` handles the raw string |

### Sign-off
When all 9 checklist items pass, **Care Anchor is complete**.
````

---

## Appendix: Implementation Order Summary

| Part | Prompts | Files Created |
|------|---------|---------------|
| **Part 1** | 1–5 | `jac.toml`, `.env`, `models/`, `data/` |
| **Part 2** | 6–10 | `services/safety_rules`, `symptom_mapper`, `transcript_parser`, `provider_matcher`, `__init__` files |
| **Part 3** | 11–15 | `agents/intervention`, `conversation`, `calling`, `diagnosis`, `messaging`, `summary` |
| **Part 4** | 16–20 | `agents/orchestrator`, `services/json_exporter`, `services/pdf_exporter`, `main.jac`, `__init__.jac`, `styles/main.css` |
| **Part 5** | 21–25 | `CrisisBanner`, `MessageBubble`, `AgentTrace`, `ExportButtons`, `ProviderCard`, `SummaryPanel` |
| **Part 6** | 26–28 | `ChatWindow`, `AppShell`, full integration test |

**Total:** 28 prompts across 6 files. Each prompt is independently verifiable with `jac check`
before proceeding to the next.
