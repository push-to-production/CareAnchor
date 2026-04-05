"""Referral Handoff Agent — builds an export-ready referral packet from session state."""

import from models.session { UserSession, ReferralHandoffPacket }
import from .summary { run_summary_agent }

def _patient_snapshot(session: UserSession) -> dict {
    return {
        "location": session.location if session.location else "",
        "insurance": session.insurance if session.insurance else "",
        "symptom_duration": session.symptom_duration if session.symptom_duration else "",
        "severity": session.severity if session.severity else "",
        "risk_flags": session.risk_flags,
        "reported_symptoms": session.extracted_symptoms
    };
}

def _ranked_provider_payload(session: UserSession) -> list {
    if session.ranked_provider_options and len(session.ranked_provider_options) > 0 {
        payload: list = [];
        for item in session.ranked_provider_options {
            provider = item["provider"] if isinstance(item, dict) else item.provider;
            score = item["score"] if isinstance(item, dict) else item.score;
            reasons = item["reasons"] if isinstance(item, dict) else item.reasons;
            payload.append({
                "name": provider.name,
                "specialty": provider.specialty,
                "phone": provider.phone,
                "address": provider.address,
                "score": score,
                "reasons": reasons
            });
        }
        return payload;
    }

    fallback: list = [];
    for provider in session.provider_options {
        fallback.append({
            "name": provider.name,
            "specialty": provider.specialty,
            "phone": provider.phone,
            "address": provider.address,
            "score": 0.0,
            "reasons": ["Ranking not generated yet."]
        });
    }
    return fallback;
}

def _next_steps(session: UserSession) -> list[str] {
    steps: list[str] = [];

    if session.provider_options and len(session.provider_options) > 0 {
        steps.append("Contact the highest-ranked provider first for scheduling.");
        steps.append("Share the symptom timeline and any current medications during intake.");
    } else {
        steps.append("Retry provider search with a more specific city/state or specialty.");
    }

    if session.intervention_active or len(session.risk_flags) > 0 {
        steps.append("Escalate to urgent support if safety risk increases.");
    }
    return steps;
}

def packet_to_dict(packet: ReferralHandoffPacket) -> dict {
    return {
        "handoff_title": packet.handoff_title,
        "referral_reason": packet.referral_reason,
        "clinical_summary": packet.clinical_summary,
        "patient_snapshot": packet.patient_snapshot,
        "ranked_providers": packet.ranked_providers,
        "next_steps": packet.next_steps,
        "export_metadata": packet.export_metadata
    };
}

def build_referral_handoff_packet(session: UserSession) -> ReferralHandoffPacket {
    session.active_agent = "Referral Handoff Agent";
    session.agent_path.append("Referral Handoff Agent:active");

    summary = run_summary_agent(session);
    reason = "Care coordination referral for follow-up evaluation.";
    if session.assigned_codes and len(session.assigned_codes) > 0 {
        first = session.assigned_codes[0];
        code = first["code"] if isinstance(first, dict) else first.code;
        desc = first["description"] if isinstance(first, dict) else first.description;
        reason = "Follow-up recommended for " + str(code) + " — " + str(desc) + ".";
    }

    packet = ReferralHandoffPacket(
        referral_reason=reason,
        clinical_summary=summary,
        patient_snapshot=_patient_snapshot(session),
        ranked_providers=_ranked_provider_payload(session),
        next_steps=_next_steps(session),
        export_metadata={
            "session_id": session.session_id,
            "generated_from": "Referral Handoff Agent",
            "ready_for_pdf": True
        }
    );

    session.referral_handoff = packet_to_dict(packet);
    session.agent_path.append("Referral Handoff Agent:completed");
    return packet;
}
