"""Intervention agent — crisis detection and state management."""

import from ..models.session { UserSession, InterventionDecision }
import from ..services.safety_rules { detect_crisis, detect_resume }

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
