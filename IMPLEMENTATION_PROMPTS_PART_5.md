# Care Anchor — Implementation Prompts Part 5
## Client Components — Leaf Components (No State)

> **Blueprint phase:** Steps 21–25 of 27  
> **Goal:** Build all leaf UI components that receive data via props and emit events.
> These have no internal async state — they are pure presentational.  
> **Prerequisite:** Parts 1–4 complete; backend verified; `styles/main.css` written.  
> **Important `.cl.jac` rules from `AGENTS.md`:**
> - Files are entirely client-side. Do NOT `include` them from server files.
> - `items.length` not `len(items)`. `String(x)` not `str(x)`. `"a" + var` not f-strings.
> - `className` not `class` in JSX.
> - `True`/`False` capitalized.
> - Empty lambda body: `lambda e: any -> None { 0; }` — never `{}`.
> - Return type: `-> JsxElement`, never `-> any`.

---

## Prompt 21 — CrisisBanner Component

````text
You are continuing to build **Care Anchor**. Parts 1–4 are complete.

### Context
`components/CrisisBanner.cl.jac` renders a high-visibility red banner when the intervention
layer detects crisis language. It is always present in the DOM but hidden when safe.

It receives two props:
- `active: bool` — whether to show the banner.
- `riskFlags: list` — list of flag strings to display as secondary text.

### File to Create: `components/CrisisBanner.cl.jac`

```jac
"""Crisis safety banner — shown when intervention_active is True."""

def:pub CrisisBanner(active: bool, riskFlags: list) -> JsxElement {
    if not active {
        return <div></div>;
    }
    return <div className="crisis-banner">
        <strong>Safety Alert</strong> — If you are in immediate danger, call <strong>911</strong> or text <strong>988</strong> (Suicide & Crisis Lifeline, free 24/7).
        {riskFlags.length > 0 and
            <div className="crisis-banner__flags">
                {[<span key={String(i)}>{flag} </span> for (i, flag) in enumerate(riskFlags)]}
            </div>
        }
    </div>;
}
```

### Verification
`jac check components/CrisisBanner.cl.jac` must pass.
The component returns an empty `<div>` when not active (not `null` — Jac JSX requires a valid element).
````

---

## Prompt 22 — MessageBubble Component

````text
You are continuing to build **Care Anchor**. Prompt 21 is complete.

### Context
`components/MessageBubble.cl.jac` renders a single message in the chat feed.
It uses different CSS classes depending on whether the message is from the user, assistant,
or a crisis/intervention message.

Props:
- `msg: dict` — a single `ChatMessage` serialized as dict with keys:
  `role`, `content`, `timestamp`, `agent`.

### File to Create: `components/MessageBubble.cl.jac`

```jac
"""Single chat message bubble."""

def bubble_class(role: str, agent: str) -> str {
    base = "bubble bubble--" + role;
    if agent == "Intervention Agent" {
        base = base + " bubble--crisis";
    }
    return base;
}

def format_time(ts: str) -> str {
    if not ts or ts == "" { return ""; }
    parts = ts.split("T");
    if parts.length < 2 { return ts; }
    time_part = parts[1].split(".")[0];
    return time_part;
}

def:pub MessageBubble(msg: dict) -> JsxElement {
    role = msg["role"] if "role" in msg else "assistant";
    content = msg["content"] if "content" in msg else "";
    timestamp = msg["timestamp"] if "timestamp" in msg else "";
    agent = msg["agent"] if "agent" in msg else "";

    return <div className={bubble_class(role, agent)}>
        <div className="bubble__body">{content}</div>
        <div className="bubble__meta">
            {agent != "" and <span>{agent} · </span>}
            <span>{format_time(timestamp)}</span>
        </div>
    </div>;
}
```

### Verification
`jac check components/MessageBubble.cl.jac` must pass.
Note: `"role" in msg` uses Python-style `in` operator which compiles correctly in Jac cl{} context.
````

---

## Prompt 23 — AgentTrace Component

````text
You are continuing to build **Care Anchor**. Prompt 22 is complete.

### Context
`components/AgentTrace.cl.jac` renders the pipeline status bar — a column of colored pills
showing which agent is active, completed, or idle.

Props:
- `trace: list` — list of dicts with keys `name: str` and `status: str`.
  Status values: `"idle"`, `"listening"`, `"active"`, `"completed"`, `"error"`.

### File to Create: `components/AgentTrace.cl.jac`

```jac
"""Agent pipeline status pills."""

def pill_class(status: str) -> str {
    match status {
        case "active": return "agent-pill agent-pill--active";
        case "completed": return "agent-pill agent-pill--completed";
        case "error": return "agent-pill agent-pill--error";
        case _: return "agent-pill";
    }
}

def status_label(status: str) -> str {
    match status {
        case "active": return "running";
        case "completed": return "done";
        case "listening": return "listening";
        case "error": return "error";
        case _: return "idle";
    }
}

def:pub AgentTrace(trace: list) -> JsxElement {
    if not trace or trace.length == 0 {
        return <div></div>;
    }
    return <div className="agent-trace">
        <h3>Pipeline</h3>
        {[<div key={item["name"]} className={pill_class(item["status"])}>
            <span className="agent-pill__dot"></span>
            <span>{item["name"]}</span>
            <span style={{"marginLeft": "auto", "opacity": "0.6", "fontSize": "0.7rem"}}>
                {status_label(item["status"])}
            </span>
        </div> for item in trace]}
    </div>;
}
```

### Verification
`jac check components/AgentTrace.cl.jac` must pass.
````

---

## Prompt 24 — ExportButtons Component

````text
You are continuing to build **Care Anchor**. Prompt 23 is complete.

### Context
`components/ExportButtons.cl.jac` renders two export buttons (JSON and PDF) and displays
a status message after a successful export.

Props:
- `sessionId: str` — current session ID; buttons are disabled when empty.
- `onJson: any` — callback for JSON export.
- `onPdf: any` — callback for PDF export.
- `exportStatus: str` — status message to display after export.

### File to Create: `components/ExportButtons.cl.jac`

```jac
"""Export JSON and PDF buttons."""

def:pub ExportButtons(sessionId: str, onJson: any, onPdf: any, exportStatus: str) -> JsxElement {
    disabled = sessionId == "";
    return <div className="export-buttons">
        <h3 style={{"fontSize": "0.75rem", "textTransform": "uppercase", "letterSpacing": "0.08em", "color": "#6b7280"}}>Export</h3>
        <button
            className="btn btn--secondary btn--sm"
            onClick={lambda e: any -> None { onJson(); }}
            disabled={disabled}
        >
            Export JSON
        </button>
        <button
            className="btn btn--secondary btn--sm"
            onClick={lambda e: any -> None { onPdf(); }}
            disabled={disabled}
        >
            Export PDF
        </button>
        {exportStatus != "" and
            <div className="export-status">{exportStatus}</div>
        }
    </div>;
}
```

### Verification
`jac check components/ExportButtons.cl.jac` must pass.
````

---

## Prompt 25 — ProviderCard & SummaryPanel Components

````text
You are continuing to build **Care Anchor**. Prompt 24 is complete.

### Context
`components/ProviderCard.cl.jac` renders a single provider result card.
`components/SummaryPanel.cl.jac` renders the right sidebar with symptoms, ICD codes,
providers, and summary text.

### File to Create: `components/ProviderCard.cl.jac`

```jac
"""Single provider result card."""

def:pub ProviderCard(provider: dict) -> JsxElement {
    name = provider["name"] if "name" in provider else "Unknown Provider";
    specialty = provider["specialty"] if "specialty" in provider else "";
    address = provider["address"] if "address" in provider else "";
    phone = provider["phone"] if "phone" in provider else "";
    telehealth = provider["telehealth_available"] if "telehealth_available" in provider else False;
    rating = provider["rating"] if "rating" in provider else 0.0;
    notes = provider["notes"] if "notes" in provider else "";

    return <div className="provider-card">
        <div className="provider-card__name">{name}</div>
        <div className="provider-card__detail">{specialty}</div>
        {address != "" and <div className="provider-card__detail">{address}</div>}
        {phone != "" and <div className="provider-card__detail">{phone}</div>}
        <div style={{"display": "flex", "gap": "4px", "flexWrap": "wrap", "marginTop": "4px"}}>
            {telehealth and <span className="provider-card__badge">Telehealth</span>}
            {rating > 0.0 and <span className="provider-card__badge">{"★ " + String(rating)}</span>}
        </div>
        {notes != "" and <div className="provider-card__detail" style={{"marginTop": "4px", "fontStyle": "italic"}}>{notes}</div>}
    </div>;
}
```

### File to Create: `components/SummaryPanel.cl.jac`

```jac
"""Right sidebar: symptoms, ICD codes, providers, summary text."""

import from .ProviderCard { ProviderCard }

def:pub SummaryPanel(session: dict) -> JsxElement {
    symptoms = session["extracted_symptoms"] if "extracted_symptoms" in session else [];
    codes = session["assigned_codes"] if "assigned_codes" in session else [];
    providers = session["provider_options"] if "provider_options" in session else [];
    summary_text = session["summary_text"] if "summary_text" in session else None;
    location = session["location"] if "location" in session else None;
    insurance = session["insurance"] if "insurance" in session else None;

    return <div className="summary-panel">
        {(location != None or insurance != None) and
            <div>
                <h3>Patient Info</h3>
                {location != None and <div className="summary-panel__item">📍 {location}</div>}
                {insurance != None and <div className="summary-panel__item">🏥 {insurance}</div>}
            </div>
        }

        {symptoms.length > 0 and
            <div>
                <h3>Reported Symptoms</h3>
                <div>{[<span key={String(i)} className="code-tag">{sym}</span> for (i, sym) in enumerate(symptoms)]}</div>
            </div>
        }

        {codes.length > 0 and
            <div>
                <h3>Matched Conditions</h3>
                {[<div key={c["code"]} style={{"marginBottom": "6px"}}>
                    <span className="code-tag">{c["code"]}</span>
                    <span style={{"fontSize": "0.8rem", "marginLeft": "6px"}}>{c["description"]}</span>
                </div> for c in codes]}
            </div>
        }

        {providers.length > 0 and
            <div>
                <h3>Matched Providers</h3>
                {[<ProviderCard key={p["name"]} provider={p} /> for p in providers]}
            </div>
        }

        {summary_text != None and summary_text != "" and
            <div>
                <h3>Summary</h3>
                <div className="summary-panel__item" style={{"fontSize": "0.82rem", "lineHeight": "1.5"}}>{summary_text}</div>
            </div>
        }

        {symptoms.length == 0 and codes.length == 0 and providers.length == 0 and
            <div style={{"color": "#6b7280", "fontSize": "0.82rem"}}>
                Describe your symptoms and I'll populate this panel.
            </div>
        }
    </div>;
}
```

### Verification
`jac check components/ProviderCard.cl.jac` must pass.
`jac check components/SummaryPanel.cl.jac` must pass.

Update `components/__init__.jac` to list all component files:
```jac
"""Care Anchor components package."""
```
(The init remains minimal — components import each other directly.)
````
