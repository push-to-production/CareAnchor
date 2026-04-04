"""Calling agent — verifies readiness for provider search."""

import from models.session { UserSession, CallingPreparation }
import from services.provider_matcher { normalize_insurance }

def run_calling_agent(session: UserSession) -> CallingPreparation {
    session.agent_path.append("Calling Agent:active");

    loc = session.location if session.location else "";
    ins = session.insurance if session.insurance else "";
    norm_ins = normalize_insurance(ins) if ins != "" else "";
    missing: list[str] = [];

    if not session.extracted_symptoms or len(session.extracted_symptoms) == 0 {
        missing.append("symptoms");
    }
    if loc == "" { missing.append("location (city and state)"); }
    if ins == "" { missing.append("insurance provider"); }

    ready = len(missing) == 0;

    note = "";
    if not ready {
        note = "Waiting for: " + ", ".join(missing) + ".";
    }

    session.agent_path.append("Calling Agent:completed");

    return CallingPreparation(
        normalized_location=loc,
        normalized_insurance=norm_ins,
        provider_search_ready=ready,
        missing_fields=missing,
        note=note
    );
}

def build_calling_follow_up(session: UserSession, prep: CallingPreparation) -> str {
    if not prep.provider_search_ready {
        if "symptoms" in prep.missing_fields {
            return "To help connect you with care, could you describe your symptoms?";
        }
        if "location (city and state)" in prep.missing_fields and "insurance provider" in prep.missing_fields {
            return "I'd also like your city/state and insurance so I can find providers near you. What are those?";
        }
        if "location (city and state)" in prep.missing_fields {
            return "What city and state are you in? I'll use that to find providers near you.";
        }
        if "insurance provider" in prep.missing_fields {
            return "Which insurance do you have? (e.g., Aetna, Blue Cross, Cigna, UnitedHealthcare, Medicare/Medicaid)";
        }
    }
    return "I have everything I need. Let me look up providers for you.";
}
