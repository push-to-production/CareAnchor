"""Conversation agent — symptom and field extraction."""

import from models.session { UserSession, ConversationStateUpdate }
import from services.transcript_parser { build_conversation_state_update }

def run_conversation_agent(session: UserSession, message: str) -> ConversationStateUpdate {
    session.active_agent = "Conversation Agent";
    session.agent_path.append("Conversation Agent:active");

    update = build_conversation_state_update(
        message=message,
        transcript_messages=session.transcript,
        known_symptoms=session.extracted_symptoms,
        known_location=session.location
    );

    for sym in update.extracted_symptoms {
        if sym not in session.extracted_symptoms {
            session.extracted_symptoms.append(sym);
        }
    }

    if update.location and update.location != "" {
        session.location = update.location;
    }
    if update.insurance and update.insurance != "" {
        session.insurance = update.insurance;
    }
    if update.duration and update.duration != "" {
        session.symptom_duration = update.duration;
    }
    if update.severity and update.severity != "" {
        session.severity = update.severity;
    }

    session.agent_path.append("Conversation Agent:completed");
    return update;
}

def minimum_fields_ready(session: UserSession) -> bool {
    has_symptoms = len(session.extracted_symptoms) > 0;
    has_location = session.location is not None and session.location != "";
    return has_symptoms and has_location;
}
