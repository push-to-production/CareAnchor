"""Calling agent — verifies readiness for provider search."""

import from models.session { UserSession, CallingPreparation }
import from services.common { transcript_excerpt }
glob LLM_READY: bool = False;

"""You are Care Anchor, a compassionate medical intake assistant. Your job is to gather enough
information to find the right healthcare providers near the patient. You MUST collect:

1. The patient's location (city and state) — required to find nearby providers
2. Enough symptom detail to determine the right specialist — ask about what the symptoms feel
   like, where exactly they occur, how long they've been going on, severity, and any related
   symptoms

Still missing: {missing_fields}
Symptoms shared so far: {symptoms}
Recent conversation:
{recent_transcript}

Write a warm, thorough response that does ALL of the following:
- Briefly acknowledge what the patient shared (1 short sentence)
- Ask for ALL missing fields together naturally
- Ask targeted symptom detail questions to build a clear clinical picture: where exactly is the
  discomfort, what does it feel like (sharp, dull, throbbing, etc.), how long has it been going
  on, how severe is it on a scale of 1-10, and are there any related symptoms (nausea, fever,
  fatigue, etc.)?

Be conversational and empathetic, not clinical. No bullet points. Do not wrap your response in
quotation marks."""
def llm_generate_follow_up(
    missing_fields: list[str],
    symptoms: list[str],
    recent_transcript: str
) -> str by llm();

def run_calling_agent(session: UserSession) -> CallingPreparation {
    session.agent_path.append("Calling Agent:active");

    loc = session.location if session.location else "";
    missing: list[str] = [];

    if not session.extracted_symptoms or len(session.extracted_symptoms) == 0 {
        missing.append("symptoms");
    }
    if loc == "" { missing.append("location (city and state)"); }

    ready = len(missing) == 0;

    note = "";
    if not ready {
        note = "Waiting for: " + ", ".join(missing) + ".";
    }

    session.agent_path.append("Calling Agent:completed");

    return CallingPreparation(
        normalized_location=loc,
        normalized_insurance="",
        provider_search_ready=ready,
        missing_fields=missing,
        note=note
    );
}

def build_calling_follow_up(session: UserSession, prep: CallingPreparation) -> str {
    if not prep.provider_search_ready {
        if LLM_READY {
            try {
                excerpt = transcript_excerpt(session.transcript, 8);
                result = llm_generate_follow_up(
                    missing_fields=prep.missing_fields,
                    symptoms=session.extracted_symptoms,
                    recent_transcript=excerpt
                );
                return result;
            } except Exception as e {
                0;
            }
        }
        prompts: list[str] = [];
        has_duration = session.symptom_duration is not None and session.symptom_duration != "";
        has_severity = session.severity is not None and session.severity != "";
        has_insurance = session.insurance is not None and session.insurance != "";

        if "location (city and state)" in prep.missing_fields {
            prompts.append("What city and state are you in so I can look for providers near you?");
        }
        if "symptoms" in prep.missing_fields {
            prompts.append("Please tell me what symptoms you're having.");
        } elif not has_duration or not has_severity {
            prompts.append("How long has this been going on, and how severe is it right now?");
        }
        if not has_insurance {
            prompts.append("If you know it, what insurance do you have?");
        }

        return "Thanks for the update. " + " ".join(prompts);
    }
    return "I have everything I need. Let me look up providers for you.";
}
