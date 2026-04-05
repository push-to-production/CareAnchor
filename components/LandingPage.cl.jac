"""Marketing landing page for AnchorCare."""

def scroll_to(section_id: str) -> None {
    target = document.getElementById(section_id);
    if target {
        target.scrollIntoView({"behavior": "smooth", "block": "start"});
    }
}

def:pub LandingPage(props: dict) -> JsxElement {
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
                </div>

                <div className="marketing-nav__actions">
                    <button type="button" className="btn btn--secondary marketing-nav__signin" onClick={lambda -> None { props["onSignIn"](); }}>Sign in</button>
                    <button type="button" className="btn btn--primary marketing-nav__cta" onClick={lambda -> None { props["onGetStarted"](); }}>Get Started</button>
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
                        <button type="button" className="btn btn--primary marketing-hero__primary" onClick={lambda -> None { props["onGetStarted"](); }}>Get Started</button>
                        <button type="button" className="btn btn--secondary marketing-hero__secondary" onClick={lambda -> None { scroll_to("dashboard-preview"); }}>View Dashboard</button>
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
                            <span className={"marketing-step__code" + (" marketing-step__code--risk" if step["code"] == "RISK" else "")}>{step["code"]}</span>
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

        <section className="marketing-section marketing-section--tinted">
            <div className="marketing-container">
                <div className="marketing-cta">
                    <div className="marketing-cta__copy">
                        <div className="marketing-pill marketing-pill--inverse">Ready to start</div>
                        <h2>Open the dedicated login page and continue into your AnchorCare dashboard.</h2>
                        <p>
                            Keep the landing experience focused on product storytelling, then move into a separate
                            authentication flow when you are ready to create an account or sign in.
                        </p>
                    </div>

                    <div className="marketing-cta__actions">
                        <button type="button" className="btn btn--light marketing-cta__primary" onClick={lambda -> None { props["onGetStarted"](); }}>Get Started</button>
                        <button type="button" className="btn btn--ghost marketing-cta__secondary" onClick={lambda -> None { props["onSignIn"](); }}>Sign In</button>
                    </div>
                </div>
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
