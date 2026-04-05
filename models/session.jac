"""Session graph node and supporting value objects."""

import from .codes { DiagnosisCode }
import from .provider { ProviderOption }

glob APP_DISCLAIMER: str = "AnchorCare is an AI-powered care coordination platform. It does not replace emergency care or professional diagnosis.";

obj ChatMessage {
    has role: str;
    has content: str;
    has timestamp: str;
    has agent: str;
}

obj CareSummary {
    has summary: str;
    has location: str;
    has insurance: str;
    has transcript_excerpt: str;
    has symptom_codes: list = [];
    has provider_options: list = [];
    has risk_flags: list[str] = [];
    has agent_path: list[str] = [];
}

obj ConversationStateUpdate {
    has follow_up_question: str;
    has extracted_symptoms: list[str] = [];
    has enough_for_diagnosis: bool = False;
    has location: str | None = None;
    has insurance: str | None = None;
    has duration: str | None = None;
    has severity: str | None = None;
}

obj InterventionDecision {
    has is_crisis: bool;
    has reason: str;
    has urgency: str;
    has response_markdown: str;
    has can_resume_if_user_declines: bool = True;
}

obj DiagnosisResult {
    has narrative_reasoning: str;
    has confidence_note: str;
    has symptom_codes: list = [];
    has inferred_specialties: list[str] = [];
    has provider_query_terms: list[str] = [];
}

obj RankedProvider {
    has provider: ProviderOption;
    has score: float = 0.0;
    has reasons: list[str] = [];
}

obj ReferralHandoffPacket {
    has handoff_title: str = "Referral Handoff";
    has referral_reason: str = "";
    has clinical_summary: str = "";
    has patient_snapshot: dict = {};
    has ranked_providers: list = [];
    has next_steps: list[str] = [];
    has export_metadata: dict = {};
}

obj CallingPreparation {
    has normalized_location: str;
    has normalized_insurance: str;
    has provider_search_ready: bool;
    has missing_fields: list[str] = [];
    has note: str = "";
}

node UserSession {
    has session_id: str;
    has created_at: str;
    has updated_at: str;
    has phone_number: str = "";
    has active_agent: str = "Conversation Agent";
    has last_user_message: str = "";
    has transcript: list = [];
    has extracted_symptoms: list[str] = [];
    has risk_flags: list[str] = [];
    has assigned_codes: list = [];
    has provider_options: list = [];
    has ranked_provider_options: list = [];
    has referral_handoff: dict = {};
    has agent_path: list[str] = [];
    has intervention_active: bool = False;
    has intervention_resolved: bool = False;
    has crisis_therapists_shown: bool = False;
    has symptom_duration: str | None = None;
    has severity: str | None = None;
    has location: str | None = None;
    has insurance: str | None = None;
    has summary_text: str | None = None;
    has doctor_notes: str | None = None;
}

def append_message(session: UserSession, role: str, content: str, agent: str, ts: str) -> None {
    msg = ChatMessage(role=role, content=content, timestamp=ts, agent=agent);
    session.transcript.append(msg);
}

def update_session_timestamp(session: UserSession, ts: str) -> None {
    session.updated_at = ts;
}

def _to_dict_msg(m: any) -> dict {
    return {
        "role": m.role,
        "content": m.content,
        "timestamp": m.timestamp,
        "agent": m.agent
    };
}

def _to_dict_code(c: any) -> dict {
    return {
        "code": c.code,
        "description": c.description,
        "category": c.category,
        "confidence": c.confidence,
        "source": c.source
    };
}

def _to_dict_provider(p: any) -> dict {
    return {
        "name": p.name,
        "specialty": p.specialty,
        "address": p.address,
        "phone": p.phone,
        "accepts_insurance": p.accepts_insurance,
        "distance_miles": p.distance_miles,
        "rating": p.rating,
        "accepting_new_patients": p.accepting_new_patients,
        "telehealth_available": p.telehealth_available,
        "notes": p.notes
    };
}

def _to_dict_ranked_provider(r: any) -> dict {
    provider = r["provider"] if isinstance(r, dict) else r.provider;
    reasons = r["reasons"] if isinstance(r, dict) else r.reasons;
    score = r["score"] if isinstance(r, dict) else r.score;
    return {
        "provider": _to_dict_provider(provider),
        "score": score,
        "reasons": reasons
    };
}

def _to_dict_referral_handoff(handoff: any) -> dict {
    if isinstance(handoff, dict) { return handoff; }
    return {
        "handoff_title": handoff.handoff_title,
        "referral_reason": handoff.referral_reason,
        "clinical_summary": handoff.clinical_summary,
        "patient_snapshot": handoff.patient_snapshot,
        "ranked_providers": handoff.ranked_providers,
        "next_steps": handoff.next_steps,
        "export_metadata": handoff.export_metadata
    };
}

def session_to_dict(session: UserSession) -> dict {
    disclaimer = APP_DISCLAIMER;
    agent_trace: list = [
        {"name": "Intervention Agent", "status": "listening"},
        {"name": "Conversation Agent", "status": "idle"},
        {"name": "Calling Agent", "status": "idle"},
        {"name": "Diagnosis Agent", "status": "idle"},
        {"name": "Provider Ranking Agent", "status": "idle"},
        {"name": "Messaging Agent", "status": "idle"},
        {"name": "Summary Agent", "status": "idle"},
        {"name": "Referral Handoff Agent", "status": "idle"}
    ];
    for step in session.agent_path {
        parts = step.split(":");
        if len(parts) > 1 {
            agent_name = parts[0];
            status = parts[1];
            for item in agent_trace {
                if item["name"] == agent_name {
                    item["status"] = status;
                }
            }
        }
    }
    transcript_list: list = [_to_dict_msg(m) for m in session.transcript];
    codes_list: list = [_to_dict_code(c) for c in session.assigned_codes];
    providers_list: list = [_to_dict_provider(p) for p in session.provider_options];
    ranked_provider_list: list = [_to_dict_ranked_provider(p) for p in session.ranked_provider_options];
    return {
        "session_id": session.session_id,
        "phone_number": session.phone_number,
        "created_at": session.created_at,
        "updated_at": session.updated_at,
        "active_agent": session.active_agent,
        "transcript": transcript_list,
        "extracted_symptoms": session.extracted_symptoms,
        "risk_flags": session.risk_flags,
        "assigned_codes": codes_list,
        "provider_options": providers_list,
        "ranked_provider_options": ranked_provider_list,
        "referral_handoff": _to_dict_referral_handoff(session.referral_handoff),
        "agent_path": session.agent_path,
        "agent_trace": agent_trace,
        "intervention_active": session.intervention_active,
        "intervention_resolved": session.intervention_resolved,
        "location": session.location,
        "insurance": session.insurance,
        "summary_text": session.summary_text,
        "doctor_notes": session.doctor_notes,
        "disclaimer": disclaimer
    };
}
