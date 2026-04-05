"""Root application shell. Owns all session and auth state."""

import "../styles/main.css";

cl import from react { useEffect }

sv import from __main__ {
    create_session,
    process_message,
    export_json,
    export_pdf,
    load_demo,
    get_user_by_token,
    logout
}

def set_auth_cookie(token: str) -> None {
    document.cookie = "care_anchor_token=" + token + "; path=/; SameSite=Strict; max-age=604800";
}

def get_auth_cookie() -> str {
    name = "care_anchor_token=";
    parts = document.cookie.split(";");
    for p in parts {
        c = p.trim();
        if c.indexOf(name) == 0 {
            return c.substring(name.length);
        }
    }
    return "";
}

def clear_auth_cookie() -> None {
    document.cookie = "care_anchor_token=; path=/; max-age=0";
}

import from .AgentTrace { AgentTrace }
import from .ChatWindow { ChatWindow }
import from .CrisisBanner { CrisisBanner }
import from .LoginScreen { LoginScreen, format_phone }
import from .SessionPdf { build_session_pdf_attachment }
import from .SummaryPanel { SummaryPanel }

def tab_class(active_tab: str, tab_name: str) -> str {
    base = "dashboard-tab";
    if active_tab == tab_name {
        return base + " dashboard-tab--active";
    }
    return base;
}

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
        "doctor_notes": None,
        "disclaimer": "AnchorCare is an AI-powered care coordination platform. It does not replace emergency care or professional diagnosis."
    };
}

def build_pdf_chat_message(payload: dict, attachment: dict) -> dict {
    timestamp = payload["generated_at"] if "generated_at" in payload else "";

    return {
        "role": "assistant",
        "content": "Your AnchorCare session summary is ready as a PDF attachment.",
        "timestamp": timestamp,
        "agent": "Summary Agent",
        "attachment": attachment
    };
}

def:pub AppShell() -> JsxElement {
    has loggedIn: bool = false;
    has phoneNumber: str = "";
    has userId: str = "";
    has authToken: str = "";
    has sessionId: str = "";
    has session: dict = empty_session();
    has draft: str = "";
    has sending: bool = False;
    has booting: bool = False;
    has exportStatus: str = "";
    has errorText: str = "";
    has activeTab: str = "chat";
    has localTranscript: list = [];

    async def bootstrap(phone: str) -> None {
        booting = True;
        errorText = "";
        exportStatus = "";
        session = empty_session();
        localTranscript = [];
        sessionId = "";
        draft = "";
        try {
            result = root spawn create_session(phone_number=phone);
            if result.reports.length > 0 {
                payload = result.reports[0];
                sessionId = payload["session_id"];
                session = payload["session"];
            } else {
                errorText = "Unable to start an AnchorCare session. Is the backend running?";
            }
        } except Exception as e {
            errorText = "Connection error. Please check that the backend is running.";
        }
        booting = False;
    }

    def handleLogin(payload: dict) -> None {
        user = payload["user"];
        token = payload["token"] if "token" in payload else "";
        phoneNumber = user["phone_number"];
        userId = user["user_id"];
        authToken = token;
        if token != "" { set_auth_cookie(token); }
        loggedIn = true;
        bootstrap(user["phone_number"]);
    }

    async def handleLogout() -> None {
        if authToken != "" {
            try { root spawn logout(token=authToken); } except Exception as e { 0; }
        }
        clear_auth_cookie();
        loggedIn = false;
        phoneNumber = "";
        userId = "";
        authToken = "";
        sessionId = "";
        session = empty_session();
        draft = "";
        errorText = "";
        exportStatus = "";
        localTranscript = [];
    }

    async def restoreSession() -> None {
        token = get_auth_cookie();
        if token == "" { return; }
        try {
            result = root spawn get_user_by_token(token=token);
            if result.reports.length > 0 {
                payload = result.reports[0];
                if "user" in payload {
                    handleLogin({"user": payload["user"], "token": token});
                } else {
                    clear_auth_cookie();
                }
            }
        } except Exception as e {
            clear_auth_cookie();
        }
    }

    useEffect(lambda -> None { restoreSession(); }, []);

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

    async def do_export_pdf() -> None {
        if sessionId == "" { return; }
        exportStatus = "Exporting...";
        try {
            result = root spawn export_pdf(session_id=sessionId);
            if result.reports.length > 0 {
                payload = result.reports[0];
                if "session" in payload {
                    session = payload["session"];
                }
                if "error" in payload {
                    exportStatus = payload["error"];
                } elif "html_content" in payload {
                    attachment = await build_session_pdf_attachment(payload);
                    if attachment != None {
                        localTranscript = localTranscript.concat([build_pdf_chat_message(payload, attachment)]);
                        exportStatus = "PDF ready in chat.";
                        activeTab = "chat";
                    } else {
                        exportStatus = "PDF export failed.";
                    }
                } else {
                    exportStatus = "PDF export failed.";
                }
            } else {
                exportStatus = "PDF export failed.";
            }
        } except Exception as e {
            exportStatus = "PDF export failed.";
        }
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

    async def run_demo(case_id: int) -> None {
        sending = True;
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

    if not loggedIn {
        return <LoginScreen onLogin={handleLogin} />;
    }

    active_agent = session["active_agent"] if "active_agent" in session else "Conversation Agent";
    intervention_active = session["intervention_active"] if "intervention_active" in session else False;
    risk_flags = session["risk_flags"] if "risk_flags" in session else [];
    disclaimer = session["disclaimer"] if "disclaimer" in session else "AnchorCare is an AI-powered care coordination platform. It does not replace emergency care or professional diagnosis.";
    transcript = session["transcript"] if "transcript" in session else [];
    providers = session["provider_options"] if "provider_options" in session else [];
    summary_text = session["summary_text"] if "summary_text" in session else "";
    session_state = "Preparing session..." if booting else "Session ready";
    combined_transcript = transcript.concat(localTranscript);

    return <div className="dashboard-shell">
        <div className="dashboard-frame">
            <header className="dashboard-header">
                <div className="dashboard-header__brand">
                    <div className="dashboard-header__logo" aria-hidden="true"></div>
                    <div className="dashboard-header__copy">
                        <div className="brand-mark">ANCHORCARE</div>
                        <h1>AnchorCare Dashboard</h1>
                        <p>{disclaimer}</p>
                    </div>
                </div>

                <div className="dashboard-header__controls">
                    <div className="session-pill">{session_state}</div>
                    <div className="dashboard-tabs">
                        <button
                            type="button"
                            className={tab_class(activeTab, "chat")}
                            onClick={lambda -> None { activeTab = "chat"; }}
                        >
                            Chat
                        </button>
                        <button
                            type="button"
                            className={tab_class(activeTab, "call")}
                            onClick={lambda -> None { activeTab = "call"; }}
                        >
                            Call
                        </button>
                    </div>
                    <div className="header-user">
                        <span className="header-phone">{format_phone(phoneNumber)}</span>
                        <button className="btn btn--sm header-signout" onClick={lambda -> None { handleLogout(); }}>Sign out</button>
                    </div>
                </div>
            </header>

            <CrisisBanner active={intervention_active} riskFlags={risk_flags} />

            {errorText != "" and
                <div className="error-banner">{errorText}</div>
            }

            <main className="dashboard-main">
                <section className="dashboard-main__primary">
                    {activeTab == "chat" and
                        <ChatWindow
                            transcript={combined_transcript}
                            draft={draft}
                            sending={sending or booting}
                            activeAgent={active_agent}
                            onDraftChange={lambda value: str -> None { draft = value; }}
                            onSend={lambda -> None { send_message(); }}
                            onDemo={lambda case_id: any -> None { run_demo(case_id); }}
                            onPdf={lambda -> None { do_export_pdf(); }}
                            onReset={lambda -> None { bootstrap(phoneNumber); }}
                            exportStatus={exportStatus}
                            exportDisabled={sessionId == ""}
                        />
                    }

                    {activeTab == "call" and
                        <div className="call-stage">
                            <div className="call-stage__badge">Voice workspace</div>
                            <h2>Ready to start a guided phone consultation?</h2>
                            <p>
                                This Jac client now matches the imported dashboard structure.
                                Voice actions are still backend-driven, so this tab currently acts
                                as a launch surface for the future call flow.
                            </p>

                            <div className="call-stage__stats">
                                <div className="call-stat">
                                    <span className="call-stat__label">Active agent</span>
                                    <strong>{active_agent}</strong>
                                </div>
                                <div className="call-stat">
                                    <span className="call-stat__label">Messages captured</span>
                                    <strong>{String(transcript.length)}</strong>
                                </div>
                                <div className="call-stat">
                                    <span className="call-stat__label">Providers matched</span>
                                    <strong>{String(providers.length)}</strong>
                                </div>
                            </div>

                            <div className="call-stage__notes">
                                <div className="call-stage__note">
                                    <h3>What is wired today</h3>
                                    <p>Chat triage, risk escalation, provider matching, and export workflows remain live.</p>
                                </div>
                                <div className="call-stage__note">
                                    <h3>Suggested next step</h3>
                                    <p>Use the chat tab to collect patient context, then continue the voice UX from this same dashboard shell.</p>
                                </div>
                            </div>
                        </div>
                    }
                </section>

                <aside className="dashboard-main__side">
                    <div className="panel panel--glass">
                        <div className="panel__eyebrow">Session overview</div>
                        <div className="overview-grid">
                            <div className="overview-stat">
                                <span>Transcript</span>
                                <strong>{String(transcript.length)}</strong>
                            </div>
                            <div className="overview-stat">
                                <span>Providers</span>
                                <strong>{String(providers.length)}</strong>
                            </div>
                            <div className="overview-stat">
                                <span>Risk flags</span>
                                <strong>{String(risk_flags.length)}</strong>
                            </div>
                            <div className="overview-stat">
                                <span>Summary</span>
                                <strong>{"Ready" if summary_text != "" else "Pending"}</strong>
                            </div>
                        </div>
                    </div>

                    <SummaryPanel session={session} />
                    <AgentTrace trace={agent_trace} />
                </aside>
            </main>
        </div>
    </div>;
}
