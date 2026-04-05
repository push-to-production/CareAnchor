"""Intervention agent — crisis detection and state management."""

import from models.session { UserSession, InterventionDecision }
import from services.safety_rules { detect_crisis, detect_resume, CRISIS_RESPONSE_MARKDOWN }
import from services.provider_matcher { find_therapists, format_therapists_markdown }

def build_crisis_reply(session: UserSession) -> str {
    base = CRISIS_RESPONSE_MARKDOWN;
    loc = session.location if session.location else "";
    if loc == "" {
        return base + "\n\n---\n\nTo help find a therapist near you, could you share your city and state?";
    }
    providers = find_therapists(loc, 5);
    therapist_section = format_therapists_markdown(providers, loc);
    return base + "\n\n---\n\n" + therapist_section;
}

def run_therapist_search(session: UserSession) -> str {
    loc = session.location if session.location else "";
    if loc == "" {
        return "To find therapists near you, could you share your city and state?";
    }
    providers = find_therapists(loc, 5);
    session.provider_options = providers;
    session.crisis_therapists_shown = True;
    return format_therapists_markdown(providers, loc);
}

def run_intervention_agent(session: UserSession, message: str) -> dict {
    decision = detect_crisis(message);
    if decision.is_crisis {
        session.intervention_active = True;
        session.intervention_resolved = False;
        session.active_agent = "Intervention Agent";
        flag = "Crisis language detected: " + decision.reason;
        if flag not in session.risk_flags {
            session.risk_flags.append(flag);
        }
        if "Intervention Agent:active" not in session.agent_path {
            session.agent_path.append("Intervention Agent:active");
        }
        reply = build_crisis_reply(session);
        if session.location and session.location != "" {
            session.crisis_therapists_shown = True;
        }
        decision.response_markdown = reply;
        return {"triggered": True, "decision": decision};
    }
    return {"triggered": False, "decision": decision};
}

def try_resume_from_intervention(session: UserSession, message: str) -> str | None {
    if not session.intervention_active { return None; }
    if session.intervention_resolved { return None; }

    if detect_resume(message) {
        session.intervention_active = False;
        session.intervention_resolved = True;
        session.active_agent = "Conversation Agent";
        session.agent_path.append("Intervention Agent:resolved");
        return "I'm glad you're safe. Let's continue — please tell me your symptoms, and your city/state and insurance when you can.";
    }
    return None;
}
