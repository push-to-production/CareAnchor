"""Agent pipeline status pills."""

def pill_class(status: str) -> str {
    match status {
        case "active": return "agent-pill agent-pill--active";
        case "completed": return "agent-pill agent-pill--completed";
        case "listening": return "agent-pill agent-pill--active";
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
    return <div className="agent-trace panel panel--glass">
        <div className="panel__eyebrow">Pipeline</div>
        {[<div key={item["name"]} className={pill_class(item["status"])}>
            <span className="agent-pill__dot"></span>
            <span>{item["name"]}</span>
            <span style={{"marginLeft": "auto", "opacity": "0.6", "fontSize": "0.72rem", "fontWeight": "700"}}>
                {status_label(item["status"])}
            </span>
        </div> for item in trace]}
    </div>;
}
