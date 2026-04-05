"""Messaging agent — formats the final user-facing reply from structured data."""

import from models.session { UserSession, DiagnosisResult }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _is_icd_code(s: str) -> bool {
    if len(s) < 3 { return False; }
    return s[0].isupper() and s[1].isdigit();
}

def _natural_symptoms(raw: list) -> list {
    result: list = [];
    for s in raw {
        words = s.strip().split();
        if words and not _is_icd_code(words[0]) {
            result.append(s);
        }
    }
    return result;
}

def _code_str(code: any) -> str {
    if isinstance(code, dict) {
        return code["code"] + " — " + code["description"];
    }
    return code.code + " — " + code.description;
}

def _provider_lines(p: any) -> list {
    if isinstance(p, dict) {
        name  = p["name"];
        spec  = p["specialty"];
        phone = p["phone"];
        tele  = p["telehealth_available"];
    } else {
        name  = p.name;
        spec  = p.specialty;
        phone = p.phone;
        tele  = p.telehealth_available;
    }
    lines: list = ["- **" + name + "** (" + spec + ") · " + phone];
    if tele { lines.append("  *Telehealth available*"); }
    return lines;
}

# ---------------------------------------------------------------------------
# Template-based reply — no LLM
# The local 7B model echoes its prompt and cannot reliably format Markdown.
# All output is derived directly from structured session data.
# ---------------------------------------------------------------------------

def run_messaging_agent(
    session: UserSession,
    diagnosis: DiagnosisResult
) -> str {
    session.active_agent = "Messaging Agent";
    session.agent_path.append("Messaging Agent:active");

    loc = session.location if session.location else "your area";
    lines: list = [];

    # What the patient reported
    readable = _natural_symptoms(session.extracted_symptoms);
    lines.append("## What I heard");
    if readable {
        lines.append("You mentioned: **" + ", ".join(readable[:5]) + "**.");
    } else {
        lines.append("I wasn't able to identify specific symptoms from your message. Please describe how you're feeling.");
    }

    # Possible related conditions
    if diagnosis.symptom_codes {
        lines.append("\n## Possible related conditions");
        lines.append("*(For informational purposes only — not a medical diagnosis)*");
        for code in diagnosis.symptom_codes[:3] {
            lines.append("- **" + _code_str(code) + "**");
        }
    }

    # Matched providers
    if session.provider_options {
        lines.append("\n## Providers near " + loc);
        for p in session.provider_options[:3] {
            for ln in _provider_lines(p) {
                lines.append(ln);
            }
        }
    } else {
        lines.append("\n*No providers found for your location. Try calling 211 for local referrals.*");
    }

    # Disclaimer
    lines.append("\n---");
    lines.append("*Care Anchor is a care coordination tool. It does not provide medical advice or diagnoses. In an emergency, call 911.*");

    session.agent_path.append("Messaging Agent:completed");
    return "\n".join(lines);
}
