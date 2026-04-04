"""Single chat message bubble."""

cl import from marked { marked }

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

def MdBody(msg: dict) -> JsxElement {
    role = msg["role"] if "role" in msg else "assistant";
    text = msg["content"] if "content" in msg else "";
    if role == "assistant" {
        html = marked(text);
        return <div className="md-body" dangerouslySetInnerHTML={{"__html": html}}></div>;
    }
    return <span>{text}</span>;
}

def:pub MessageBubble(msg: dict) -> JsxElement {
    role = msg["role"] if "role" in msg else "assistant";
    timestamp = msg["timestamp"] if "timestamp" in msg else "";
    agent = msg["agent"] if "agent" in msg else "";

    return <div className={bubble_class(role, agent)}>
        <div className="bubble__body"><MdBody msg={msg} /></div>
        <div className="bubble__meta">
            {agent != "" and <span>{agent} · </span>}
            <span>{format_time(timestamp)}</span>
        </div>
    </div>;
}
