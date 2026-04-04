"""Summary agent — generates CareSummary and export helpers."""

import from os { getenv }
import from models.session { UserSession, CareSummary }
import from services.common { transcript_excerpt, APP_DISCLAIMER }

glob LLM_READY: bool = (getenv("OPENAI_API_KEY") or "") != "";

"""Write a 3-sentence plain-English care coordination summary for a patient.
Include: what symptoms were reported, what conditions were identified, and what
next steps were recommended. Do not diagnose. Do not include provider names.
Keep it under 120 words."""
def llm_generate_summary(
    symptoms: list[str],
    codes: list[str],
    specialties: list[str],
    location: str,
    insurance: str
) -> str by llm();

def run_summary_agent(session: UserSession) -> str {
    session.agent_path.append("Summary Agent:active");

    code_labels: list[str] = [];
    for c in session.assigned_codes {
        if isinstance(c, dict) {
            code_labels.append(c["code"] + " " + c["description"]);
        } else {
            code_labels.append(c.code + " " + c.description);
        }
    }
    specs: list[str] = [];
    for p in session.provider_options {
        spec = p["specialty"] if isinstance(p, dict) else p.specialty;
        if spec not in specs { specs.append(spec); }
    }

    summary = "";
    if LLM_READY and session.extracted_symptoms {
        try {
            summary = llm_generate_summary(
                symptoms=session.extracted_symptoms,
                codes=code_labels,
                specialties=specs,
                location=session.location if session.location else "",
                insurance=session.insurance if session.insurance else ""
            );
        } except Exception as e {
            0;
        }
    }

    if not summary or summary.strip() == "" {
        parts: list[str] = [];
        if session.extracted_symptoms {
            parts.append("Reported symptoms: " + ", ".join(session.extracted_symptoms[:5]) + ".");
        }
        if code_labels {
            parts.append("Possible conditions: " + ", ".join(code_labels[:3]) + ".");
        }
        if session.provider_options {
            parts.append(str(len(session.provider_options)) + " provider(s) matched.");
        }
        summary = " ".join(parts) if parts else "Session summary pending.";
    }

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
