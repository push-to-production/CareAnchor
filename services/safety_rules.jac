"""Crisis phrase matching — no LLM, no network, always fast."""

import from ..models.session { InterventionDecision }
import from .common { normalize_text }

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

def detect_crisis(message: str) -> InterventionDecision {
    normalized = normalize_text(message);
    for phrase in CRISIS_PHRASES {
        if phrase in normalized {
            return InterventionDecision(
                is_crisis=True,
                reason="self-harm or suicidal language detected",
                urgency="high",
                response_markdown="**Immediate support**\n\nI'm sorry you're going through this. If you're in immediate danger, call **911** or go to the nearest emergency room.\n\nIn the U.S., call or text **988** right now for the Suicide & Crisis Lifeline — it's free and available 24/7.\n\n**Are you in immediate danger right now?**",
                can_resume_if_user_declines=True
            );
        }
    }
    return InterventionDecision(
        is_crisis=False,
        reason="no crisis phrases detected",
        urgency="routine",
        response_markdown="",
        can_resume_if_user_declines=True
    );
}

def detect_resume(message: str) -> bool {
    normalized = normalize_text(message);
    for phrase in RESUME_PHRASES {
        if phrase in normalized { return True; }
    }
    return False;
}
