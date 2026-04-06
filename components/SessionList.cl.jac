"""Session history list — shows past sessions for the logged-in user."""

def format_date(iso_str: str) -> str {
    if not iso_str or iso_str == "" { return ""; }
    parts = iso_str.split("T");
    date_part = parts[0] if parts.length > 0 else "";
    time_part = parts[1].substring(0, 5) if parts.length > 1 else "";
    return date_part + " " + time_part;
}

def:pub SessionList(props: dict) -> JsxElement {
    sessions = props["sessions"] if "sessions" in props else [];
    current_id = props["currentSessionId"] if "currentSessionId" in props else "";
    on_select = props["onSelect"];
    on_new = props["onNew"];

    if sessions.length == 0 {
        return <section className="session-list panel">
            <div className="session-list__header">
                <div className="session-list__heading">
                    <div className="panel__eyebrow">Conversation history</div>
                    <h2 className="session-list__title">Recent sessions</h2>
                </div>
                <button className="btn btn--primary btn--sm session-list__new-btn" onClick={lambda -> None { on_new(); }}>+ New</button>
            </div>
            <div className="session-list__empty">
                <p className="session-list__empty-text">No previous sessions yet. Start a new conversation to begin tracking care coordination.</p>
                <button className="btn btn--primary session-list__empty-btn" onClick={lambda -> None { on_new(); }}>Start new session</button>
            </div>
        </section>;
    }

    return <section className="session-list panel">
        <div className="session-list__header">
            <div className="session-list__heading">
                <div className="panel__eyebrow">Conversation history</div>
                <h2 className="session-list__title">Recent sessions</h2>
            </div>
            <button className="btn btn--primary btn--sm session-list__new-btn" onClick={lambda -> None { on_new(); }}>+ New</button>
        </div>
        <ul className="session-list__items">
            {[<li
                key={s["session_id"]}
                className={"session-item" + (" session-item--active" if s["session_id"] == current_id else "") + (" session-item--crisis" if s["intervention_active"] else "")}
                onClick={lambda -> None { on_select(s["session_id"]); }}
            >
                <div className="session-item__preview">{s["preview"] if s["preview"] != "" else "Empty session"}</div>
                <div className="session-item__meta">
                    <span>{format_date(s["updated_at"])}</span>
                    <span>{String(s["message_count"]) + " msgs"}</span>
                </div>
                {s["symptoms"].length > 0 and
                    <div className="session-item__tags">
                        {[<span key={sym} className="session-item__tag">{sym}</span> for sym in s["symptoms"]]}
                    </div>
                }
            </li> for s in sessions]}
        </ul>
    </section>;
}
