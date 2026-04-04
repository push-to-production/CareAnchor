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
