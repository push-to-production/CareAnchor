"""Summary agent — generates a grounded care coordination summary."""

import from models.session { UserSession, CareSummary }
import from services.common { transcript_excerpt }

def _is_icd_code(s: str) -> bool {
    if len(s) < 3 { return False; }
    first_upper = s[0].isupper();
    second_digit = s[1].isdigit();
    return first_upper and second_digit;
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

def _build_summary(session: UserSession, code_labels: list, specs: list) -> str {
    parts: list = [];

    readable = _natural_symptoms(session.extracted_symptoms);
    if readable {
        parts.append("The patient reported: " + ", ".join(readable[:5]) + ".");
    } elif session.extracted_symptoms {
        parts.append("The patient reported " + str(len(session.extracted_symptoms)) + " symptom(s).");
    }

    if code_labels {
        parts.append("Conditions considered: " + "; ".join(code_labels[:3]) + ".");
    }

    if specs {
        step = "Referral to " + " or ".join(specs[:2]) + " recommended for further evaluation.";
        parts.append(step);
    } elif session.provider_options {
        parts.append(str(len(session.provider_options)) + " provider(s) matched for follow-up.");
    }

    if not parts {
        return "Session summary pending.";
    }
    return " ".join(parts);
}

def run_summary_agent(session: UserSession) -> str {
    if not session.location or session.location.strip() == "" {
        return session.summary_text if session.summary_text else "";
    }
    if not session.assigned_codes or len(session.assigned_codes) == 0 {
        return session.summary_text if session.summary_text else "";
    }

    session.agent_path.append("Summary Agent:active");

    code_labels: list = [];
    for c in session.assigned_codes {
        if isinstance(c, dict) {
            code_labels.append(c["code"] + " — " + c["description"]);
        } else {
            code_labels.append(c.code + " — " + c.description);
        }
    }

    specs: list = [];
    for p in session.provider_options {
        spec = p["specialty"] if isinstance(p, dict) else p.specialty;
        if spec not in specs { specs.append(spec); }
    }

    summary = _build_summary(session, code_labels, specs);
    session.summary_text = summary;
    session.agent_path.append("Summary Agent:completed");
    return summary;
}

def build_care_summary(session: UserSession) -> CareSummary {
    excerpt = transcript_excerpt(session.transcript, 6);
    return CareSummary(
        symptom_codes=session.assigned_codes,
        provider_options=session.provider_options,
        summary=session.summary_text if session.summary_text else "",
        location=session.location if session.location else "",
        insurance=session.insurance if session.insurance else "",
        risk_flags=session.risk_flags,
        agent_path=session.agent_path,
        transcript_excerpt=excerpt
    );
}
