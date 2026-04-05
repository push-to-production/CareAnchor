"""Builds session-based PDF payloads for client-side rendering."""

import from models.session { UserSession }
import from .common { iso_now, APP_DISCLAIMER, transcript_excerpt }

def _escape_html(value: str) -> str {
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#39;")
    );
}

def _bullet_items(values: list, fallback: str) -> str {
    if len(values) == 0 {
        return "<p>" + _escape_html(fallback) + "</p>";
    }
    items: list[str] = [];
    for raw in values {
        text = str(raw).strip();
        items.append("<li>" + _escape_html(text) + "</li>");
    }
    return "<ul>" + "".join(items) + "</ul>";
}

def _symptom_items(session: UserSession) -> str {
    return _bullet_items(session.extracted_symptoms, "No patient-reported symptoms were captured.");
}

def _risk_flag_items(session: UserSession) -> str {
    return _bullet_items(session.risk_flags, "No active risk flags were recorded for this session.");
}

def _code_items(session: UserSession) -> str {
    if len(session.assigned_codes) == 0 {
        return "<p>No provisional diagnosis or ICD-related outputs were recorded.</p>";
    }

    items: list[str] = [];
    for raw in session.assigned_codes {
        code = raw["code"] if isinstance(raw, dict) else raw.code;
        description = raw["description"] if isinstance(raw, dict) else raw.description;
        confidence = raw["confidence"] if isinstance(raw, dict) else raw.confidence;

        detail = str(code).strip() if code != None else "Code unavailable";
        description_text = str(description).strip() if description != None else "Description unavailable";
        confidence_text = str(confidence).strip() if confidence != None else "";

        line = "<strong>" + _escape_html(detail) + "</strong>: " + _escape_html(description_text);
        if confidence_text != "" {
            line += " (" + _escape_html(confidence_text) + ")";
        }
        items.append("<li>" + line + "</li>");
    }
    return "<ul>" + "".join(items) + "</ul>";
}

def _provider_items(session: UserSession) -> str {
    if len(session.provider_options) == 0 {
        return "<p>No provider recommendations are available for this session yet.</p>";
    }

    items: list[str] = [];
    for raw in session.provider_options {
        name = raw["name"] if isinstance(raw, dict) else raw.name;
        specialty = raw["specialty"] if isinstance(raw, dict) else raw.specialty;
        phone = raw["phone"] if isinstance(raw, dict) else raw.phone;
        address = raw["address"] if isinstance(raw, dict) else raw.address;
        notes = raw["notes"] if isinstance(raw, dict) else raw.notes;

        detail: list[str] = [
            "<strong>" + _escape_html(str(name).strip() if name != None else "Provider") + "</strong>",
            _escape_html(str(specialty).strip() if specialty != None else "Specialty not listed")
        ];
        phone_text = str(phone).strip() if phone != None else "";
        address_text = str(address).strip() if address != None else "";
        notes_text = str(notes).strip() if notes != None else "";
        if phone_text != "" { detail.append(_escape_html(phone_text)); }
        if address_text != "" { detail.append(_escape_html(address_text)); }
        provider_html = "<li>" + " | ".join(detail);
        if notes_text != "" {
            provider_html += "<br/><em>" + _escape_html(notes_text) + "</em>";
        }
        provider_html += "</li>";
        items.append(provider_html);
    }
    return "<ul>" + "".join(items) + "</ul>";
}

def _transcript_items(session: UserSession) -> str {
    if len(session.transcript) == 0 {
        return "<p>No conversation transcript is available for this session.</p>";
    }

    items: list[str] = [];
    for raw in session.transcript {
        role = raw["role"] if isinstance(raw, dict) else raw.role;
        timestamp = raw["timestamp"] if isinstance(raw, dict) else raw.timestamp;
        content = raw["content"] if isinstance(raw, dict) else raw.content;
        agent = raw["agent"] if isinstance(raw, dict) else raw.agent;

        speaker = (str(role).strip() if role != None else "unknown").upper();
        meta = speaker;
        agent_text = str(agent).strip() if agent != None else "";
        timestamp_text = str(timestamp).strip() if timestamp != None else "";
        content_text = str(content).strip() if content != None else "";
        if agent_text != "" and speaker != "USER" {
            meta += " · " + agent_text;
        }
        if timestamp_text != "" {
            meta += " · " + timestamp_text;
        }
        items.append(
            "<li><strong>"
            + _escape_html(meta)
            + "</strong><br/>"
            + _escape_html(content_text)
            + "</li>"
        );
    }
    return "<ol>" + "".join(items) + "</ol>";
}

def _clinical_brief(session: UserSession) -> str {
    summary_text = str(session.summary_text) if session.summary_text != None else "";
    if summary_text.strip() != "" {
        return summary_text.strip();
    }

    parts: list[str] = [];
    if len(session.extracted_symptoms) > 0 {
        parts.append("Patient-reported symptoms include " + ", ".join(session.extracted_symptoms[:6]) + ".");
    }
    location = str(session.location) if session.location != None else "";
    if location.strip() != "" {
        parts.append("Reported location: " + location.strip() + ".");
    }
    insurance = str(session.insurance) if session.insurance != None else "";
    if insurance.strip() != "" {
        parts.append("Insurance on file: " + insurance.strip() + ".");
    }
    if len(session.provider_options) > 0 {
        parts.append(str(len(session.provider_options)) + " provider recommendation(s) are available for follow-up.");
    }
    return " ".join(parts) if len(parts) > 0 else "Clinical brief pending for this session.";
}

def _care_summary(session: UserSession) -> str {
    parts: list[str] = [];
    if len(session.extracted_symptoms) > 0 {
        parts.append("Symptoms reviewed: " + ", ".join(session.extracted_symptoms[:5]) + ".");
    }
    if len(session.assigned_codes) > 0 {
        first = session.assigned_codes[0];
        code = first["code"] if isinstance(first, dict) else first.code;
        description = first["description"] if isinstance(first, dict) else first.description;
        code_text = str(code).strip() if code != None else "Unknown code";
        description_text = str(description).strip() if description != None else "";
        parts.append("Top provisional match: " + code_text + " " + description_text + ".");
    }
    if len(session.provider_options) > 0 {
        parts.append("Provider recommendations are ready for care coordination follow-up.");
    }
    if len(session.risk_flags) > 0 {
        parts.append("Safety review flagged: " + ", ".join(session.risk_flags) + ".");
    } else {
        parts.append("No active safety escalation flags were recorded in the latest session state.");
    }
    return " ".join(parts);
}

def _doctor_notes(session: UserSession) -> str {
    doctor_notes = str(session.doctor_notes) if session.doctor_notes != None else "";
    if doctor_notes.strip() != "" {
        return doctor_notes.strip();
    }
    return "None available for this session.";
}

def _session_html(session: UserSession, generated_at: str) -> str {
    transcript_summary = transcript_excerpt(session.transcript, 8);
    clinical_brief = _clinical_brief(session);
    care_summary = _care_summary(session);
    doctor_notes = _doctor_notes(session);

    sections: list[str] = [
        "<section><h1>AnchorCare Session Report</h1><p>"
        + _escape_html(APP_DISCLAIMER)
        + "</p></section>",
        "<section><h2>Session Details</h2><ul>"
        + "<li><strong>Session ID:</strong> " + _escape_html(session.session_id) + "</li>"
        + "<li><strong>Created:</strong> " + _escape_html(session.created_at) + "</li>"
        + "<li><strong>Last Updated:</strong> " + _escape_html(session.updated_at) + "</li>"
        + "<li><strong>Exported:</strong> " + _escape_html(generated_at) + "</li>"
        + "</ul></section>",
        "<section><h2>Patient-Reported Symptoms</h2>" + _symptom_items(session) + "</section>",
        "<section><h2>Conversation Transcript Summary</h2><p>"
        + _escape_html(transcript_summary if transcript_summary != "" else "No transcript summary available.")
        + "</p></section>",
        "<section><h2>Conversation Transcript</h2>" + _transcript_items(session) + "</section>",
        "<section><h2>Clinical Brief</h2><p>" + _escape_html(clinical_brief) + "</p></section>",
        "<section><h2>Provider Recommendations</h2>" + _provider_items(session) + "</section>",
        "<section><h2>Risk Flags</h2>" + _risk_flag_items(session) + "</section>",
        "<section><h2>Provisional Diagnosis / ICD Outputs</h2>" + _code_items(session) + "</section>",
        "<section><h2>Doctor Notes</h2><p>" + _escape_html(doctor_notes) + "</p></section>",
        "<section><h2>Care Summary</h2><p>" + _escape_html(care_summary) + "</p></section>",
        "<section><h2>Safety Note</h2><p>" + _escape_html(APP_DISCLAIMER) + "</p></section>"
    ];
    return "".join(sections);
}

def build_session_pdf_payload(session: UserSession) -> dict {
    generated_at = iso_now();
    return {
        "file_name": "anchorcare_session_" + session.session_id + ".pdf",
        "mime_type": "application/pdf",
        "generated_at": generated_at,
        "session_id": session.session_id,
        "disclaimer": APP_DISCLAIMER,
        "html_content": _session_html(session, generated_at)
    };
}
