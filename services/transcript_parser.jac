"""Structured field extraction from free-text messages."""

import re;
import from os { getenv }
import from models.session { ConversationStateUpdate }
import from .common { first_non_empty, merge_strings, normalize_text, transcript_excerpt }
import from .symptom_mapper { extract_symptom_keywords, codes_from_keywords }

glob LLM_READY: bool = True;

glob INSURANCE_ALIASES: dict[str, list[str]] = {
    "Aetna": ["aetna"],
    "Blue Cross Blue Shield": ["blue cross", "blue shield", "bcbs", "blue cross blue shield"],
    "Cigna": ["cigna"],
    "UnitedHealthcare": ["unitedhealthcare", "united healthcare", "uhc"],
    "Humana": ["humana"],
    "Medicare": ["medicare"],
    "Medicaid": ["medicaid"]
};

def rule_extract_insurance(text: str) -> str {
    lower = text.lower();
    for canonical in INSURANCE_ALIASES {
        aliases = INSURANCE_ALIASES[canonical];
        for alias in aliases {
            if alias in lower { return canonical; }
        }
    }
    return "";
}

def rule_extract_location(text: str) -> str {
    lower = text.lower();
    state_patterns = [
        "austin, tx", "austin tx", "denver, co", "denver co",
        "new york", "los angeles", "chicago", "houston", "phoenix",
        "philadelphia", "san antonio", "san diego", "dallas", "san jose"
    ];
    for pattern in state_patterns {
        if pattern in lower { return pattern.title(); }
    }
    return "";
}

def rule_extract_duration(text: str) -> str {
    lower = text.lower();
    patterns = ["for two days", "for a week", "since yesterday", "since last", "for three days",
                "for a few days", "for months", "for years", "since this morning"];
    for p in patterns {
        if p in lower { return p; }
    }
    return "";
}

def rule_extract_severity(text: str) -> str {
    lower = text.lower();
    if any([w in lower for w in ["severe", "excruciating", "unbearable", "worst"]]) { return "severe"; }
    if any([w in lower for w in ["moderate", "medium", "noticeable"]]) { return "moderate"; }
    if any([w in lower for w in ["mild", "slight", "minor", "a little"]]) { return "mild"; }
    return "";
}

"""You are a medical intake coordinator. Extract structured care coordination fields from the
user message and conversation history. Do NOT diagnose. Do NOT speculate beyond what the user
explicitly states.

Fields to extract:
- extracted_symptoms: list of symptom phrases (verbatim from user)
- follow_up_question: a single clarifying question to ask next (location if missing,
  insurance if missing, duration if missing, severity if missing, or "" if all known)
- enough_for_diagnosis: True only if we have at least 2 symptoms AND location AND insurance
- location: city and state or zip code, or None
- insurance: normalized insurance name or None
- duration: how long symptoms have been present, or None
- severity: "mild" | "moderate" | "severe" | None

Return a ConversationStateUpdate object. Never fabricate information not present in the message."""
def llm_extract_fields(
    message: str,
    recent_transcript: str,
    known_symptoms: list[str],
    known_location: str,
    known_insurance: str
) -> ConversationStateUpdate by llm();

def build_conversation_state_update(
    message: str,
    transcript_messages: list,
    known_symptoms: list[str],
    known_location: str | None,
    known_insurance: str | None
) -> ConversationStateUpdate {
    loc_str = known_location if known_location else "";
    ins_str = known_insurance if known_insurance else "";

    rule_ins = rule_extract_insurance(message);
    rule_loc = rule_extract_location(message);
    rule_dur = rule_extract_duration(message);
    rule_sev = rule_extract_severity(message);
    rule_codes = extract_symptom_keywords(message);

    merged_loc = first_non_empty(rule_loc, loc_str);
    merged_ins = first_non_empty(rule_ins, ins_str);
    merged_symptoms = list(known_symptoms);
    for code in rule_codes {
        if code not in merged_symptoms { merged_symptoms.append(code); }
    }

    if LLM_READY {
        try {
            excerpt = transcript_excerpt(transcript_messages, 6);
            llm_result = llm_extract_fields(
                message, excerpt, merged_symptoms, merged_loc, merged_ins
            );
            final_loc = first_non_empty(llm_result.location if llm_result.location else "", merged_loc);
            final_ins = first_non_empty(llm_result.insurance if llm_result.insurance else "", merged_ins);
            all_syms = list(merged_symptoms);
            for s in llm_result.extracted_symptoms {
                if s not in all_syms { all_syms.append(s); }
            }
            ready = (len(all_syms) >= 1 and final_loc != "" and final_ins != "");
            return ConversationStateUpdate(
                extracted_symptoms=all_syms,
                follow_up_question=llm_result.follow_up_question,
                enough_for_diagnosis=ready,
                location=final_loc if final_loc != "" else None,
                insurance=final_ins if final_ins != "" else None,
                duration=llm_result.duration if llm_result.duration else rule_dur if rule_dur else None,
                severity=llm_result.severity if llm_result.severity else rule_sev if rule_sev else None
            );
        } except Exception as e {
            0;
        }
    }

    missing: list[str] = [];
    if not merged_loc or merged_loc == "" { missing.append("location (city and state)"); }
    if not merged_ins or merged_ins == "" { missing.append("insurance provider"); }
    if not merged_symptoms { missing.append("a description of your symptoms"); }

    follow_up = "";
    if missing { follow_up = "Could you share your " + missing[0] + "?"; }
    ready = (len(merged_symptoms) >= 1 and merged_loc != "" and merged_ins != "");

    return ConversationStateUpdate(
        extracted_symptoms=merged_symptoms,
        follow_up_question=follow_up,
        enough_for_diagnosis=ready,
        location=merged_loc if merged_loc != "" else None,
        insurance=merged_ins if merged_ins != "" else None,
        duration=rule_dur if rule_dur != "" else None,
        severity=rule_sev if rule_sev != "" else None
    );
}
