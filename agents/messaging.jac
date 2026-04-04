"""Messaging agent — formats the final user-facing reply."""

import from os { getenv }
import from models.session { UserSession, DiagnosisResult, CareSummary }
import from models.codes { DiagnosisCode }
import from models.provider { ProviderOption }

glob LLM_READY: bool = (getenv("OPENAI_API_KEY") or "") != "";

"""Format a concise, empathetic care coordination reply in Markdown.
Include: a brief summary of what was heard, a section listing the 2-3 most relevant
ICD codes with plain-English descriptions, a section listing up to 3 provider options
with name/specialty/phone/insurance note, and a closing disclaimer that this is not a
medical diagnosis. Use ## headings. Keep total length under 600 words."""
def llm_format_reply(
    symptoms: list[str],
    codes: list[DiagnosisCode],
    providers: list[ProviderOption],
    location: str,
    insurance: str,
    narrative: str
) -> str by llm();

def run_messaging_agent(
    session: UserSession,
    diagnosis: DiagnosisResult,
    summary_text: str
) -> str {
    session.active_agent = "Messaging Agent";
    session.agent_path.append("Messaging Agent:active");

    loc = session.location if session.location else "your area";
    ins = session.insurance if session.insurance else "your insurance";

    if LLM_READY and diagnosis.symptom_codes {
        try {
            reply = llm_format_reply(
                symptoms=session.extracted_symptoms,
                codes=diagnosis.symptom_codes,
                providers=session.provider_options,
                location=loc,
                insurance=ins,
                narrative=diagnosis.narrative_reasoning
            );
            session.agent_path.append("Messaging Agent:completed");
            return reply;
        } except Exception as e {
            0;
        }
    }

    lines: list[str] = [];
    lines.append("## What I heard");
    if session.extracted_symptoms {
        lines.append("You mentioned: **" + ", ".join(session.extracted_symptoms[:5]) + "**.");
    } else {
        lines.append("I wasn't able to identify specific symptoms. Please describe how you're feeling.");
    }

    if diagnosis.symptom_codes {
        lines.append("\n## Possible related conditions");
        lines.append("*(For informational purposes only — not a diagnosis)*");
        for code in diagnosis.symptom_codes[:3] {
            code_str = code["code"] + " — " + code["description"] if isinstance(code, dict) else code.code + " — " + code.description;
            lines.append("- **" + code_str + "**");
        }
    }

    if session.provider_options {
        lines.append("\n## Providers near " + loc + " accepting " + ins);
        for p in session.provider_options[:3] {
            if isinstance(p, dict) {
                pname = p["name"];
                pspec = p["specialty"];
                pphone = p["phone"];
                ptele = p["telehealth_available"];
            } else {
                pname = p.name;
                pspec = p.specialty;
                pphone = p.phone;
                ptele = p.telehealth_available;
            }
            lines.append("- **" + pname + "** (" + pspec + ") · " + pphone);
            if ptele { lines.append("  *Telehealth available*"); }
        }
    } else {
        lines.append("\n*No providers found for your location and insurance. Try calling 211 for local referrals.*");
    }

    lines.append("\n---");
    lines.append("*Care Anchor is a care coordination tool. It does not provide medical advice or diagnoses. In an emergency, call 911.*");

    session.agent_path.append("Messaging Agent:completed");
    return "\n".join(lines);
}
