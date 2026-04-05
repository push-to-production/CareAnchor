"""Public walkers — POST /walker/<Name> endpoints."""

import from models.session {
    UserSession, append_message, session_to_dict, update_session_timestamp
}
import from services.common { new_session_id, iso_now }
import from .conversation { minimum_fields_ready, run_conversation_agent }
import from .intervention { run_intervention_agent, try_resume_from_intervention, run_therapist_search }
import from .calling { run_calling_agent, build_calling_follow_up }
import from .diagnosis { run_diagnosis_agent }
import from .messaging { run_messaging_agent }

def find_session(sid: str) -> UserSession | None {
    anchor = root();
    sessions = [candidate for candidate in [anchor -->](?:UserSession) if candidate.session_id == sid];
    if sessions { return sessions[0]; }
    return None;
}

def build_payload(session: UserSession, reply: str, crisis: bool) -> dict {
    return {
        "session_id": session.session_id,
        "reply_markdown": reply,
        "session": session_to_dict(session),
        "crisis": crisis
    };
}

def run_pipeline(session: UserSession, message: str) -> dict {
    now = iso_now();
    append_message(session, "user", message, "User", now);
    session.last_user_message = message;
    update_session_timestamp(session, now);

    intervention = run_intervention_agent(session, message);
    if intervention["triggered"] {
        decision = intervention["decision"];
        reply = decision.response_markdown;
        append_message(session, "assistant", reply, "Intervention Agent", iso_now());
        return build_payload(session, reply, True);
    }

    resumed = try_resume_from_intervention(session, message);
    if resumed != None {
        append_message(session, "assistant", resumed, "Conversation Agent", iso_now());
        return build_payload(session, resumed, False);
    }

    if session.intervention_active {
        run_conversation_agent(session, message);
        if not session.crisis_therapists_shown and session.location and session.location != "" {
            reply = run_therapist_search(session);
            append_message(session, "assistant", reply, "Intervention Agent", iso_now());
            return build_payload(session, reply, True);
        }
        hold = "**Safety check** — Are you safe right now? If in immediate danger call **911** or text **988**.\n\nCould you share your city and state so I can find a therapist near you?";
        append_message(session, "assistant", hold, "Intervention Agent", iso_now());
        return build_payload(session, hold, True);
    }

    run_conversation_agent(session, message);
    calling = run_calling_agent(session);

    if not calling.provider_search_ready {
        reply = build_calling_follow_up(session, calling);
        append_message(session, "assistant", reply, "Calling Agent", iso_now());
        return build_payload(session, reply, False);
    }

    diagnosis = run_diagnosis_agent(session);
    reply = run_messaging_agent(session, diagnosis);
    append_message(session, "assistant", reply, "Messaging Agent", iso_now());
    return build_payload(session, reply, False);
}

walker :pub create_session {
    has phone_number: str = "";

    can start with Root entry {
        sid = new_session_id();
        now = iso_now();
        created = root ++> UserSession(session_id=sid, phone_number=self.phone_number, created_at=now, updated_at=now);
        session = created[0];
        session.active_agent = "Conversation Agent";
        session.agent_path = ["Conversation Agent:active"];
        welcome = "Hi, I'm AnchorCare. Tell me your symptoms and share your city/state so I can find providers near you.";
        append_message(session, "assistant", welcome, "Conversation Agent", now);
        session.agent_path.append("Conversation Agent:completed");
        commit();
        report build_payload(session, welcome, False);
    }
}

walker :pub process_message {
    has session_id: str;
    has message: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found", "session_id": self.session_id};
            disengage;
        }
        payload = run_pipeline(session, self.message);
        commit();
        report payload;
    }
}

walker :pub get_session {
    has session_id: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found"};
            disengage;
        }
        report {"session_id": session.session_id, "session": session_to_dict(session)};
    }
}

walker :pub export_json {
    has session_id: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found"};
            disengage;
        }
        import from services.json_exporter { write_session_json }
        path = write_session_json(session);
        commit();
        report {"file_path": path, "session_id": self.session_id};
    }
}

walker :pub export_pdf {
    has session_id: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found"};
            disengage;
        }
        import from services.pdf_exporter { build_session_pdf_payload }
        payload = build_session_pdf_payload(session);
        payload["session"] = session_to_dict(session);
        commit();
        report payload;
    }
}

walker :pub list_sessions {
    has phone_number: str;

    can start with Root entry {
        anchor = root();
        all_sessions = [s for s in [anchor -->](?:UserSession) if s.phone_number == self.phone_number];
        summaries: list = [];
        for s in all_sessions {
            msg_count = len(s.transcript);
            first_user_msg = "";
            for m in s.transcript {
                role = m["role"] if isinstance(m, dict) else m.role;
                content = m["content"] if isinstance(m, dict) else m.content;
                if role == "user" {
                    first_user_msg = content[:80];
                    break;
                }
            }
            summaries.append({
                "session_id": s.session_id,
                "created_at": s.created_at,
                "updated_at": s.updated_at,
                "message_count": msg_count,
                "preview": first_user_msg,
                "location": s.location,
                "symptoms": s.extracted_symptoms[:3],
                "intervention_active": s.intervention_active
            });
        }
        summaries.sort(key=lambda x: x["updated_at"], reverse=True);
        report {"sessions": summaries};
    }
}

walker :pub load_session {
    has session_id: str;

    can start with Root entry {
        session = find_session(self.session_id);
        if session == None {
            report {"error": "Session not found"};
            disengage;
        }
        report build_payload(session, "", False);
    }
}

walker :pub load_demo {
    has case_id: int = 1;

    can start with Root entry {
        sid = new_session_id();
        now = iso_now();
        created = root ++> UserSession(session_id=sid, created_at=now, updated_at=now);
        session = created[0];
        messages = [
            "I've been dizzy for two days and I missed one of my blood pressure pills. I'm in Austin, TX.",
            "I've had nausea and stomach pain since yesterday evening. I'm in Denver, CO.",
            "I feel like I want to die. Nothing is worth it anymore."
        ];
        msg = messages[0];
        if self.case_id == 2 { msg = messages[1]; }
        elif self.case_id == 3 { msg = messages[2]; }
        payload = run_pipeline(session, msg);
        commit();
        report payload;
    }
}
