"""Diagnosis agent — ICD-10-CM code matching and provider search."""

import from models.session { UserSession, DiagnosisResult }
import from services.symptom_mapper { build_diagnosis_result }
import from services.provider_matcher { find_providers }
import from services.common { transcript_excerpt }

def run_diagnosis_agent(session: UserSession) -> DiagnosisResult {
    session.active_agent = "Diagnosis Agent";
    session.agent_path.append("Diagnosis Agent:active");

    excerpt = transcript_excerpt(session.transcript, 8);
    result = build_diagnosis_result(session.extracted_symptoms, excerpt);

    session.assigned_codes = result.symptom_codes;

    loc = session.location if session.location else "";
    ins = session.insurance if session.insurance else "";

    providers = find_providers(
        diagnosis=result,
        location=loc,
        insurance=ins,
        max_results=4
    );
    session.provider_options = providers;

    session.agent_path.append("Diagnosis Agent:completed");
    return result;
}
