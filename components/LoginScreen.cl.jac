"""Landing page with embedded phone number + password auth form."""

sv import from __main__ { register_or_login }

def:pub format_phone(raw: str) -> str {
    digits = "";
    for ch in raw {
        if ch >= "0" and ch <= "9" { digits = digits + ch; }
    }
    digits = digits[:10];
    n = digits.length;
    if n == 0 { return ""; }
    if n <= 3 { return "(" + digits; }
    if n <= 6 { return "(" + digits[:3] + ") " + digits[3:]; }
    return "(" + digits[:3] + ") " + digits[3:6] + "-" + digits[6:];
}

def scroll_to(section_id: str) -> None {
    target = document.getElementById(section_id);
    if target {
        target.scrollIntoView({"behavior": "smooth", "block": "start"});
    }
}

def:pub LoginScreen(props: dict) -> JsxElement {
    has phone: str = "";
    has password: str = "";
    has loading: bool = false;
    has error: str = "";

    steps = [
        {
            "eyebrow": "01",
            "code": "INT",
            "title": "Describe symptoms",
            "description": "Walk through a guided intake that captures what you are feeling in plain language."
        },
        {
            "eyebrow": "02",
            "code": "MAP",
            "title": "Get matched",
            "description": "AnchorCare uses insurance and location context to suggest realistic next-care options."
        },
        {
            "eyebrow": "03",
            "code": "RISK",
            "title": "Escalate urgent risk",
            "description": "Built-in crisis detection highlights emergencies and points people to immediate support."
        },
        {
            "eyebrow": "04",
            "code": "PDF",
            "title": "Export the visit",
            "description": "Generate structured summaries that are ready for provider handoff in PDF or JSON."
        }
    ];

    features = [
        {
            "code": "SYM",
            "title": "Guided symptom intake",
            "description": "A Jac-powered conversation flow that captures symptoms, insurance, and care context without forcing clinical jargon."
        },
        {
            "code": "PRV",
            "title": "Smart provider matching",
            "description": "Match by specialty, distance, and coverage so users get practical care options instead of generic advice."
        },
        {
            "code": "SAFE",
            "title": "Safety guardrails",
            "description": "Escalation logic flags crisis indicators and keeps emergency guidance explicit when risk is high."
        },
        {
            "code": "SUM",
            "title": "Shareable summaries",
            "description": "Turn the conversation into structured artifacts that providers and care teams can actually use."
        }
    ];

    metrics = [
        {"value": "<2 min", "label": "from intake to next steps"},
        {"value": "Real-time", "label": "risk detection in the loop"},
        {"value": "PDF + JSON", "label": "handoff-ready outputs"},
        {"value": "Jac-native", "label": "built in one full-stack runtime"}
    ];

    activity = [
        {"tone": "marketing-activity__dot--teal", "text": "Care summary exported for a completed session", "time": "2 min ago"},
        {"tone": "marketing-activity__dot--blue", "text": "Provider shortlist generated from insurance and zip code", "time": "15 min ago"},
        {"tone": "marketing-activity__dot--mint", "text": "Urgent-risk banner triggered and surfaced guidance", "time": "1 hour ago"}
    ];

    async def handleSubmit() -> None {
        digits = "";
        for ch in phone {
            if ch >= "0" and ch <= "9" { digits = digits + ch; }
        }
        trimmed_phone = digits;
        if trimmed_phone == "" {
            error = "Please enter your phone number.";
            return;
        }
        if password == "" {
            error = "Please enter your password.";
            return;
        }
        loading = true;
        error = "";
        try {
            result = root spawn register_or_login(phone_number=trimmed_phone, password=password);
            if result.reports.length > 0 {
                payload = result.reports[0];
                if "error" in payload {
                    error = payload["error"];
                } else {
                    props["onLogin"](payload);
                }
            } else {
                error = "Unable to sign in. Is the backend running?";
            }
        } except Exception as e {
            error = "Connection error. Please try again.";
        }
        loading = false;
    }

    def handleKeyDown(e: dict) -> None {
        if e["key"] == "Enter" { handleSubmit(); }
    }

    btn_label: str = "Signing in..." if loading else "Continue";

    return <div className="marketing-page">
        <div className="marketing-page__bg" aria-hidden="true">
            <div className="marketing-orb marketing-orb--one"></div>
            <div className="marketing-orb marketing-orb--two"></div>
            <div className="marketing-orb marketing-orb--three"></div>
        </div>

        <nav className="marketing-nav">
            <div className="marketing-container marketing-nav__inner">
                <div className="marketing-brand">
                    <div className="marketing-brand__mark" aria-hidden="true"></div>
                    <div className="marketing-brand__copy">
                        <span className="marketing-brand__name">AnchorCare</span>
                        <span className="marketing-brand__tag">Care coordination for uncertain moments</span>
                    </div>
                </div>

                <div className="marketing-nav__links">
                    <a href="#how-it-works" className="marketing-nav__link">How it works</a>
                    <a href="#features" className="marketing-nav__link">Features</a>
                    <a href="#why-anchorcare" className="marketing-nav__link">Why AnchorCare</a>
                    <button type="button" className="btn btn--primary marketing-nav__cta" onClick={lambda -> None { scroll_to("auth"); }}>Get started</button>
                </div>
            </div>
        </nav>

        <section className="marketing-hero">
            <div className="marketing-container marketing-hero__grid">
                <div className="marketing-hero__copy">
                    <div className="login-kicker">Jac-powered care coordination</div>
                    <h1 className="marketing-hero__title">
                        Turn symptoms, uncertainty, and follow-up chaos into structured next steps.
                    </h1>
                    <p className="marketing-hero__text">
                        AnchorCare guides people from symptom intake to provider matching, crisis escalation,
                        and export-ready summaries inside one Jac application.
                    </p>

                    <div className="marketing-hero__actions">
                        <button type="button" className="btn btn--primary marketing-hero__primary" onClick={lambda -> None { scroll_to("auth"); }}>Create account</button>
                        <button type="button" className="btn btn--secondary marketing-hero__secondary" onClick={lambda -> None { scroll_to("dashboard-preview"); }}>View dashboard</button>
                    </div>

                    <p className="marketing-hero__note">
                        AnchorCare supports care coordination and triage. It does not replace emergency care or professional diagnosis.
                    </p>

                    <div className="marketing-metrics">
                        {[<div key={item["value"]} className="marketing-metric">
                            <strong>{item["value"]}</strong>
                            <span>{item["label"]}</span>
                        </div> for item in metrics]}
                    </div>
                </div>

                <div className="marketing-preview">
                    <div className="marketing-preview__frame panel panel--glass">
                        <div className="marketing-preview__header">
                            <div>
                                <div className="panel__eyebrow">Live dashboard preview</div>
                                <h2>AnchorCare command center</h2>
                            </div>
                            <div className="marketing-preview__status">Session ready</div>
                        </div>

                        <div className="marketing-preview__stats">
                            <div className="marketing-preview__stat">
                                <span>Active sessions</span>
                                <strong>3</strong>
                            </div>
                            <div className="marketing-preview__stat">
                                <span>Providers matched</span>
                                <strong>12</strong>
                            </div>
                            <div className="marketing-preview__stat">
                                <span>Exports created</span>
                                <strong>8</strong>
                            </div>
                        </div>

                        <div className="marketing-preview__activity">
                            <div className="panel__eyebrow">Recent activity</div>
                            {[<div key={item["text"]} className="marketing-activity">
                                <span className={"marketing-activity__dot " + item["tone"]}></span>
                                <div>
                                    <p>{item["text"]}</p>
                                    <span>{item["time"]}</span>
                                </div>
                            </div> for item in activity]}
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <section id="how-it-works" className="marketing-section">
            <div className="marketing-container">
                <div className="marketing-section__head">
                    <div className="marketing-pill">How it works</div>
                    <h2>From symptom intake to care handoff in four steps</h2>
                </div>

                <div className="marketing-step-grid">
                    {[<article key={step["title"]} className="marketing-card marketing-step">
                        <div className="marketing-step__meta">
                            <span className="marketing-step__index">{step["eyebrow"]}</span>
                            <span className="marketing-step__code">{step["code"]}</span>
                        </div>
                        <h3>{step["title"]}</h3>
                        <p>{step["description"]}</p>
                    </article> for step in steps]}
                </div>
            </div>
        </section>

        <section id="features" className="marketing-section marketing-section--tinted">
            <div className="marketing-container">
                <div className="marketing-section__head marketing-section__head--wide">
                    <div className="marketing-pill">Features</div>
                    <h2>Everything the app needs to explain and coordinate care clearly</h2>
                    <p>
                        The landing page speaks to what AnchorCare does today: structured intake, provider matching,
                        crisis handling, and exportable summaries in a single workflow.
                    </p>
                </div>

                <div className="marketing-feature-grid">
                    {[<article key={feature["title"]} className="marketing-card marketing-feature">
                        <div className="marketing-feature__icon">{feature["code"]}</div>
                        <h3>{feature["title"]}</h3>
                        <p>{feature["description"]}</p>
                    </article> for feature in features]}
                </div>
            </div>
        </section>

        <section id="why-anchorcare" className="marketing-section">
            <div className="marketing-container">
                <div className="marketing-section__head">
                    <div className="marketing-pill">Why AnchorCare</div>
                    <h2>Built for clarity when care decisions feel fragmented</h2>
                </div>

                <div className="marketing-value-grid">
                    <div className="marketing-value">
                        <strong>Speed</strong>
                        <p>Users move from uncertainty to next steps quickly instead of bouncing between search results, portals, and phone calls.</p>
                    </div>
                    <div className="marketing-value">
                        <strong>Trust</strong>
                        <p>Safety messaging stays visible, urgent risk is not buried, and the system is explicit about what it can and cannot do.</p>
                    </div>
                    <div className="marketing-value">
                        <strong>Coordination</strong>
                        <p>Session summaries, provider options, and structured notes stay in one Jac-driven workspace for follow-through.</p>
                    </div>
                    <div className="marketing-value">
                        <strong>Explainability</strong>
                        <p>The app is not a black box pitch deck. It shows concrete workflow outputs users can understand and share.</p>
                    </div>
                </div>
            </div>
        </section>

        <section id="dashboard-preview" className="marketing-section marketing-section--tinted">
            <div className="marketing-container">
                <div className="marketing-dashboard panel panel--glass">
                    <div className="marketing-dashboard__copy">
                        <div className="marketing-pill">Dashboard preview</div>
                        <h2>A single workspace for triage, routing, and follow-through</h2>
                        <p>
                            The same app shell handles chat-based intake, matched providers, urgent-risk banners,
                            and summary exports. The landing page makes that value legible before a user signs in.
                        </p>
                    </div>

                    <div className="marketing-dashboard__image-frame">
                        <img
                            className="marketing-dashboard__image"
                            src="/dashboard-preview.png"
                            alt="AnchorCare dashboard preview showing the chat workspace and session overview panels."
                        />
                    </div>

                    <div className="marketing-dashboard__grid">
                        <div className="marketing-dashboard__panel">
                            <span>Care conversation</span>
                            <strong>Structured symptom intake with live agent routing</strong>
                        </div>
                        <div className="marketing-dashboard__panel">
                            <span>Provider options</span>
                            <strong>Insurance-aware results with practical next-care choices</strong>
                        </div>
                        <div className="marketing-dashboard__panel">
                            <span>Safety layer</span>
                            <strong>Crisis escalation stays visible when risk indicators appear</strong>
                        </div>
                        <div className="marketing-dashboard__panel">
                            <span>Exports</span>
                            <strong>PDF and JSON handoff artifacts for providers and records</strong>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <section id="auth" className="marketing-section marketing-section--auth">
            <div className="marketing-container marketing-auth">
                <section className="marketing-auth__hero">
                    <div className="marketing-pill marketing-pill--inverse">Get started</div>
                    <h2>Sign in or create an account to enter the care coordination workspace.</h2>
                    <p>
                        Use your phone number and password to continue into the Jac dashboard for symptom intake,
                        provider matching, crisis escalation, and export-ready care summaries.
                    </p>

                    <div className="marketing-auth__highlights">
                        <div className="marketing-auth__highlight">
                            <span>Guided triage</span>
                            <strong>Structured symptom intake</strong>
                        </div>
                        <div className="marketing-auth__highlight">
                            <span>Provider matching</span>
                            <strong>Location and insurance-aware routing</strong>
                        </div>
                        <div className="marketing-auth__highlight">
                            <span>Clinical exports</span>
                            <strong>PDF and JSON handoff artifacts</strong>
                        </div>
                    </div>
                </section>

                <section className="login-card panel marketing-auth__card">
                    <div className="login-badge">Secure access</div>
                    <h2 className="login-heading">Sign in or create an account</h2>
                    <p className="login-subcopy">Use your phone number and password to enter the dashboard.</p>

                    {error != "" and
                        <div className="error-banner login-error">{error}</div>
                    }

                    <div className="login-field">
                        <label className="login-label" htmlFor="phone">Phone number</label>
                        <input
                            id="phone"
                            type="tel"
                            className="login-input"
                            placeholder="(555) 000-0000"
                            value={phone}
                            onChange={lambda e -> None { phone = format_phone(e["target"]["value"]); }}
                            onKeyDown={handleKeyDown}
                            disabled={loading}
                        />
                    </div>

                    <div className="login-field">
                        <label className="login-label" htmlFor="password">Password</label>
                        <input
                            id="password"
                            type="password"
                            className="login-input"
                            placeholder="Enter your password"
                            value={password}
                            onChange={lambda e -> None { password = e["target"]["value"]; }}
                            onKeyDown={handleKeyDown}
                            disabled={loading}
                        />
                    </div>

                    <button
                        type="button"
                        className="btn btn--primary login-btn"
                        onClick={lambda -> None { handleSubmit(); }}
                        disabled={loading}
                    >
                        {btn_label}
                    </button>

                    <p className="login-note">New here? Enter your phone number and a password to register on first login.</p>
                </section>
            </div>
        </section>

        <footer className="marketing-footer">
            <div className="marketing-container marketing-footer__inner">
                <div className="marketing-brand">
                    <div className="marketing-brand__mark marketing-brand__mark--sm" aria-hidden="true"></div>
                    <div className="marketing-brand__copy">
                        <span className="marketing-brand__name">AnchorCare</span>
                        <span className="marketing-brand__tag">AI-assisted care coordination built with Jac</span>
                    </div>
                </div>
                <p className="marketing-footer__text">
                    AnchorCare supports care coordination and triage. It does not replace emergency care or professional diagnosis.
                </p>
                <p className="marketing-footer__copyright">© 2026 AnchorCare</p>
            </div>
        </footer>
    </div>;
}
