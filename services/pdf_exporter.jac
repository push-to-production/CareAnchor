"""Builds session-based PDF payloads for client-side rendering."""

import from models.session { UserSession }
import from .common { iso_now, APP_DISCLAIMER }

def _escape_html(value: str) -> str {
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#39;")
    );
}

def _fmt_time(ts: str) -> str {
    # "2026-04-05T07:23:04.356057+00:00" → "07:23"
    if not ts or ts == "" { return ""; }
    idx = ts.find("T");
    if idx == -1 { return ts[:16]; }
    return ts[idx + 1 : idx + 6];
}

def _fmt_date(ts: str) -> str {
    # "2026-04-05T07:23:04..." → "2026-04-05"
    if not ts or ts == "" { return ""; }
    idx = ts.find("T");
    if idx == -1 { return ts; }
    return ts[:idx];
}

def _css() -> str {
    return """<style>
body { font-family: Helvetica; font-size: 10pt; color: #1a2e40; line-height: 1.55; }
h2 {
    font-size: 12pt; font-weight: bold; color: #174f96;
    margin-top: 20pt; margin-bottom: 6pt;
    padding-bottom: 4pt; border-bottom-width: 1pt; border-bottom-color: #cddff0; border-bottom-style: solid;
}
p { margin-top: 0; margin-bottom: 5pt; }
ul { margin-top: 2pt; margin-bottom: 8pt; padding-left: 14pt; }
li { margin-bottom: 3pt; }
.section-intro { color: #4a6070; font-size: 9pt; margin-bottom: 6pt; }
.kv-row { margin-bottom: 3pt; }
.kv-label { font-weight: bold; color: #4a6070; }
.msg-block { margin-bottom: 10pt; }
.msg-header { font-size: 8.5pt; color: #70869a; margin-bottom: 2pt; }
.msg-header-patient { font-size: 8.5pt; color: #174f96; margin-bottom: 2pt; font-weight: bold; }
.msg-body { font-size: 10pt; }
.msg-divider { border-top-width: 1pt; border-top-color: #edf2f7; border-top-style: solid; margin-bottom: 10pt; }
.provider-name { font-weight: bold; }
.provider-meta { color: #4a6070; font-size: 9pt; }
.code-id { font-weight: bold; color: #174f96; }
.flag-item { color: #c0392b; }
.disclaimer { font-size: 8.5pt; color: #70869a; font-style: italic; }
</style>""";
}

def _summary_section(session: UserSession) -> str {
    parts: list[str] = [];

    if session.summary_text and session.summary_text.strip() != "" {
        parts.append(_escape_html(session.summary_text.strip()));
    } else {
        syms: list[str] = [];
        for s in session.extracted_symptoms[:5] { syms.append(_escape_html(str(s).strip())); }
        if syms { parts.append("The patient reported: " + ", ".join(syms) + "."); }

        if session.assigned_codes and len(session.assigned_codes) > 0 {
            first = session.assigned_codes[0];
            code = first["code"] if isinstance(first, dict) else first.code;
            desc = first["description"] if isinstance(first, dict) else first.description;
            parts.append("Top provisional match: " + _escape_html(str(code)) + " — " + _escape_html(str(desc)) + ".");
        }
        if session.provider_options and len(session.provider_options) > 0 {
            parts.append(str(len(session.provider_options)) + " provider recommendation(s) available.");
        }
        if session.risk_flags and len(session.risk_flags) > 0 {
            parts.append("Safety review flagged: " + _escape_html(", ".join(session.risk_flags)) + ".");
        } else {
            parts.append("No active safety flags recorded.");
        }
    }

    if not parts { return "<p>Clinical summary pending.</p>"; }
    return "<p>" + " ".join(parts) + "</p>";
}

def _patient_info_section(session: UserSession) -> str {
    rows: list[str] = [];
    loc = str(session.location).strip() if session.location else "";
    ins = str(session.insurance).strip() if session.insurance else "";
    dur = str(session.symptom_duration).strip() if session.symptom_duration else "";
    sev = str(session.severity).strip() if session.severity else "";

    if loc != "" { rows.append('<p class="kv-row"><span class="kv-label">Location: </span>' + _escape_html(loc) + "</p>"); }
    if ins != "" { rows.append('<p class="kv-row"><span class="kv-label">Insurance: </span>' + _escape_html(ins) + "</p>"); }
    if dur != "" { rows.append('<p class="kv-row"><span class="kv-label">Duration: </span>' + _escape_html(dur) + "</p>"); }
    if sev != "" { rows.append('<p class="kv-row"><span class="kv-label">Severity: </span>' + _escape_html(sev) + "</p>"); }

    if not rows { return "<p>No patient information recorded.</p>"; }
    return "".join(rows);
}

def _symptoms_section(session: UserSession) -> str {
    if not session.extracted_symptoms or len(session.extracted_symptoms) == 0 {
        return "<p>No patient-reported symptoms captured.</p>";
    }
    items: list[str] = [];
    for s in session.extracted_symptoms {
        items.append("<li>" + _escape_html(str(s).strip()) + "</li>");
    }
    return "<ul>" + "".join(items) + "</ul>";
}

def _conditions_section(session: UserSession) -> str {
    if not session.assigned_codes or len(session.assigned_codes) == 0 {
        return "<p>No provisional diagnosis outputs recorded.</p>";
    }
    items: list[str] = [];
    for raw in session.assigned_codes {
        code = raw["code"] if isinstance(raw, dict) else raw.code;
        desc = raw["description"] if isinstance(raw, dict) else raw.description;
        conf = raw["confidence"] if isinstance(raw, dict) else raw.confidence;
        code_str = _escape_html(str(code).strip() if code else "—");
        desc_str = _escape_html(str(desc).strip() if desc else "");
        conf_str = str(conf).strip() if conf else "";
        line = '<span class="code-id">' + code_str + "</span> — " + desc_str;
        if conf_str != "" { line += " <span>(" + _escape_html(conf_str) + ")</span>"; }
        items.append("<li>" + line + "</li>");
    }
    return "<ul>" + "".join(items) + "</ul>";
}

def _providers_section(session: UserSession) -> str {
    if not session.provider_options or len(session.provider_options) == 0 {
        return "<p>No provider recommendations available yet.</p>";
    }
    items: list[str] = [];
    for raw in session.provider_options {
        name     = str(raw["name"] if isinstance(raw, dict) else raw.name).strip();
        spec     = str(raw["specialty"] if isinstance(raw, dict) else raw.specialty).strip();
        phone    = str(raw["phone"] if isinstance(raw, dict) else raw.phone).strip();
        address  = str(raw["address"] if isinstance(raw, dict) else raw.address).strip();
        notes    = str(raw["notes"] if isinstance(raw, dict) else raw.notes).strip();

        block = '<li><p class="provider-name">' + _escape_html(name) + "</p>";
        block += '<p class="provider-meta">' + _escape_html(spec);
        if phone != "" and phone != "None" { block += " · " + _escape_html(phone); }
        block += "</p>";
        if address != "" and address != "None" {
            block += '<p class="provider-meta">' + _escape_html(address) + "</p>";
        }
        if notes != "" and notes != "None" {
            block += '<p class="provider-meta">' + _escape_html(notes) + "</p>";
        }
        block += "</li>";
        items.append(block);
    }
    return "<ul>" + "".join(items) + "</ul>";
}

def _transcript_section(session: UserSession) -> str {
    if not session.transcript or len(session.transcript) == 0 {
        return "<p>No conversation transcript available.</p>";
    }
    blocks: list[str] = [];
    for raw in session.transcript {
        role      = str(raw["role"] if isinstance(raw, dict) else raw.role).strip().lower();
        content   = str(raw["content"] if isinstance(raw, dict) else raw.content).strip();
        agent     = str(raw["agent"] if isinstance(raw, dict) else raw.agent).strip();
        timestamp = str(raw["timestamp"] if isinstance(raw, dict) else raw.timestamp).strip();

        time_str = _fmt_time(timestamp);
        if role == "user" {
            header_class = "msg-header-patient";
            speaker_label = "Patient";
        } else {
            header_class = "msg-header";
            speaker_label = agent if agent != "" else "Care Anchor";
        }
        header = speaker_label;
        if time_str != "" { header += " · " + time_str; }

        block = '<div class="msg-block">';
        block += '<p class="' + header_class + '">' + _escape_html(header) + "</p>";
        block += '<p class="msg-body">' + _escape_html(content) + "</p>";
        block += "</div>";
        block += '<div class="msg-divider"></div>';
        blocks.append(block);
    }
    return "".join(blocks);
}

def _risk_section(session: UserSession) -> str {
    if not session.risk_flags or len(session.risk_flags) == 0 {
        return "<p>No active risk flags recorded for this session.</p>";
    }
    items: list[str] = [];
    for f in session.risk_flags {
        items.append('<li class="flag-item">' + _escape_html(str(f).strip()) + "</li>");
    }
    return "<ul>" + "".join(items) + "</ul>";
}

def _session_html(session: UserSession, generated_at: str) -> str {
    date_str = _fmt_date(session.created_at);
    time_str = _fmt_time(session.created_at);

    meta_rows = (
        '<p class="kv-row"><span class="kv-label">Session ID: </span>' + _escape_html(session.session_id) + "</p>"
        + '<p class="kv-row"><span class="kv-label">Date: </span>' + _escape_html(date_str) + " at " + _escape_html(time_str) + " UTC</p>"
        + '<p class="kv-row"><span class="kv-label">Exported: </span>' + _escape_html(_fmt_date(generated_at)) + " at " + _escape_html(_fmt_time(generated_at)) + " UTC</p>"
    );

    sections: list[str] = [
        _css(),
        "<h2>Clinical Summary</h2>" + _summary_section(session),
        "<h2>Session Details</h2>" + meta_rows,
        "<h2>Patient Information</h2>" + _patient_info_section(session),
        "<h2>Reported Symptoms</h2>" + _symptoms_section(session),
        "<h2>Matched Conditions</h2>"
            + '<p class="section-intro">For informational purposes only — not a medical diagnosis.</p>'
            + _conditions_section(session),
        "<h2>Provider Recommendations</h2>" + _providers_section(session),
        "<h2>Risk &amp; Safety Flags</h2>" + _risk_section(session),
        "<h2>Conversation Transcript</h2>" + _transcript_section(session),
        '<p class="disclaimer">' + _escape_html(APP_DISCLAIMER) + "</p>"
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
