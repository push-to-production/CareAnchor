"""Shared utility functions and constants — no LLM, no graph ops."""

import uuid;
import from datetime { datetime, timezone }

glob APP_DISCLAIMER: str = "Care Anchor supports care coordination. It does not replace emergency care or professional diagnosis.";

def new_session_id() -> str {
    return str(uuid.uuid4());
}

def iso_now() -> str {
    return datetime.now(timezone.utc).isoformat();
}

def normalize_text(text: str) -> str {
    return text.lower().strip().replace("'", "").replace(",", "").replace(".", "");
}

def first_non_empty(a: str, b: str) -> str {
    if a and a.strip() != "" { return a.strip(); }
    return b.strip();
}

def merge_strings(existing: str, incoming: str) -> str {
    if not existing or existing.strip() == "" { return incoming.strip(); }
    if not incoming or incoming.strip() == "" { return existing.strip(); }
    return existing.strip();
}

def truncate(text: str, max_chars: int) -> str {
    if len(text) <= max_chars { return text; }
    return text[:max_chars] + "...";
}

def transcript_excerpt(messages: list, max_messages: int) -> str {
    n = len(messages);
    recent = messages[-max_messages:] if n > max_messages else messages;
    lines: list = [];
    for m in recent {
        if isinstance(m, dict) {
            lines.append(m["role"].upper() + ": " + m["content"]);
        } else {
            lines.append(m.role.upper() + ": " + m.content);
        }
    }
    return "\n".join(lines);
}
