"""Crisis detection — LLM semantic understanding with phrase-match fallback."""

import from models.session { InterventionDecision }
import from .common { normalize_text }
import from byllm.lib { Model }


glob CRISIS_RESPONSE_MARKDOWN: str = "**Immediate support**\n\nI'm sorry you're going through this. If you're in immediate danger, call **911** or go to the nearest emergency room.\n\nIn the U.S., call or text **988** right now for the Suicide & Crisis Lifeline — it's free and available 24/7.\n\n**Are you in immediate danger right now?**";

glob CRISIS_PHRASES: list[str] = [
    "i want to kill myself",
    "i want to die",
    "im suicidal",
    "i m suicidal",
    "i want to hurt myself",
    "i dont want to live anymore",
    "i do not want to live anymore",
    "i want to end it",
    "i might hurt myself",
    "i feel like i want to die",
    "nothing is worth it anymore",
    "i cant go on",
    "i can not go on",
    "end my life",
    "no reason to live"
];

glob RESUME_PHRASES: list[str] = [
    "no im good",
    "no i m good",
    "i m okay",
    "im okay",
    "i m safe",
    "im safe",
    "i m fine now",
    "im fine now",
    "no thanks",
    "i dont need help",
    "i do not need help",
    "i am safe",
    "i am okay",
    "i am fine"
];

"""You are a crisis safety monitor embedded in a medical care coordination app. Your sole job
is to assess whether a user's message indicates they may be experiencing a mental health crisis
that requires immediate safety intervention — such as suicidal ideation, self-harm urges, or
expressions of hopelessness or despair severe enough that the person may be at risk of harming
themselves.

Set is_crisis=True ONLY if the message clearly suggests the person may intentionally harm
themselves, no longer wants to live, or is expressing active suicidal or self-harm intent.

Set is_crisis=False for ALL of the following:
- Physical injuries or accidents (broken bones, cuts, burns, sprains, etc.)
- Normal medical complaints (pain, illness, fever, nausea, dizziness, etc.)
- Chronic conditions or symptoms (headaches, back pain, stomach issues, etc.)
- Figurative speech ("I'm dying of hunger", "this headache is killing me")
- General frustration, sadness, or stress without self-harm intent
- Questions about mental health in the abstract
- Describing past self-harm without current intent

Do NOT flag physical injuries as crisis. "I broke my wrist" is NOT a crisis.
Do NOT flag symptoms as crisis. "I have chest pain" is NOT a crisis.

Set reason to a short phrase describing why you made the decision.
Set urgency to "high" if is_crisis is True, otherwise "routine".
Set response_markdown to an empty string — it will be filled in separately.
Set can_resume_if_user_declines to True."""
def llm_assess_crisis(message: str) -> InterventionDecision by llm();

def detect_crisis(message: str) -> InterventionDecision {
    try {
        result = llm_assess_crisis(message);
        if result.is_crisis {
            return InterventionDecision(
                is_crisis=True,
                reason=result.reason,
                urgency="high",
                response_markdown=CRISIS_RESPONSE_MARKDOWN,
                can_resume_if_user_declines=True
            );
        }
        return InterventionDecision(
            is_crisis=False,
            reason=result.reason,
            urgency="routine",
            response_markdown="",
            can_resume_if_user_declines=True
        );
    } except Exception as e {
        normalized = normalize_text(message);
        for phrase in CRISIS_PHRASES {
            if phrase in normalized {
                return InterventionDecision(
                    is_crisis=True,
                    reason="self-harm or suicidal language detected",
                    urgency="high",
                    response_markdown=CRISIS_RESPONSE_MARKDOWN,
                    can_resume_if_user_declines=True
                );
            }
        }
        return InterventionDecision(
            is_crisis=False,
            reason="no crisis language detected",
            urgency="routine",
            response_markdown="",
            can_resume_if_user_declines=True
        );
    }
}

def detect_resume(message: str) -> bool {
    normalized = normalize_text(message);
    for phrase in RESUME_PHRASES {
        if phrase in normalized { return True; }
    }
    return False;
}
