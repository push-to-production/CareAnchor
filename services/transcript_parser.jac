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

def _title_case_words(text: str) -> str {
    parts = text.strip().split();
    titled: list[str] = [];
    for part in parts {
        clean = part.strip();
        if clean == "" { continue; }
        titled.append(clean[0].upper() + clean[1:].lower());
    }
    return " ".join(titled);
}

def _normalize_state_token(token: str) -> str {
    clean = token.strip();
    if clean == "" { return ""; }
    if len(clean) == 2 { return clean.upper(); }
    return _title_case_words(clean);
}

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
    # Accept common free-form variants like "denver, co" or "Portland, Maine".
    matches = re.findall(
        r'\b([A-Za-z]+(?:\s+[A-Za-z]+){0,2}),\s*([A-Za-z]{2})\b',
        text,
        flags=re.IGNORECASE
    );
    if not matches {
        matches = re.findall(
            r'\b([A-Za-z]+(?:\s+[A-Za-z]+){0,2}),\s*([A-Za-z]+(?:\s+[A-Za-z]+)*)\b',
            text,
            flags=re.IGNORECASE
        );
    }
    if matches {
        locations: list[str] = [];
        for m in matches {
            city = _title_case_words(m[0]);
            state = _normalize_state_token(m[1]);
            loc = city + ", " + state;
            if loc not in locations {
                locations.append(loc);
            }
        }
        return " or ".join(locations);
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
  duration if missing, severity if missing, or "" if all known)
- enough_for_diagnosis: True only if we have at least 1 symptom AND location
- location: ALL locations the user mentions they can be seen in, normalized to
  "City, ST" format with the official USPS two-letter state abbreviation
  (e.g. "San Francisco, CA", "New York, NY", "Chicago, IL").
  If the user names a well-known city without a state, infer the primary state
  (e.g. "San Francisco" → "San Francisco, CA", "Miami" → "Miami, FL").
  If the user gives multiple locations, join them with " or "
  (e.g. "Seattle, WA or Portland, OR"). Return None if no location is mentioned.
- duration: how long symptoms have been present, or None
- severity: "mild" | "moderate" | "severe" | None

Return a ConversationStateUpdate object. Never fabricate information not present in the message."""
def llm_extract_fields(
    message: str,
    recent_transcript: str,
    known_symptoms: list[str],
    known_location: str
) -> ConversationStateUpdate by llm();

def build_conversation_state_update(
    message: str,
    transcript_messages: list,
    known_symptoms: list[str],
    known_location: str | None
) -> ConversationStateUpdate {
    loc_str = known_location if known_location else "";

    rule_loc = rule_extract_location(message);
    rule_ins = rule_extract_insurance(message);
    rule_dur = rule_extract_duration(message);
    rule_sev = rule_extract_severity(message);
    rule_codes = extract_symptom_keywords(message);

    merged_loc = first_non_empty(rule_loc, loc_str);
    merged_symptoms = list(known_symptoms);
    for code in rule_codes {
        if code not in merged_symptoms { merged_symptoms.append(code); }
    }

    if LLM_READY {
        try {
            excerpt = transcript_excerpt(transcript_messages, 6);
            llm_result = llm_extract_fields(
                message, excerpt, merged_symptoms, merged_loc
            );
            llm_loc = llm_result.location if llm_result.location else "";
            # Only trust LLM location if the city name actually appears in the message
            # — prevents the local model hallucinating cities like "Seattle" from "i hurt my leg"
            llm_city = llm_loc.split(",")[0].lower().strip() if llm_loc else "";
            llm_loc_grounded = llm_city != "" and llm_city in message.lower();
            effective_llm_loc = llm_loc if llm_loc_grounded else "";
            final_loc = first_non_empty(merged_loc, effective_llm_loc);
            all_syms = list(merged_symptoms);
            for s in llm_result.extracted_symptoms {
                if s not in all_syms { all_syms.append(s); }
            }
            ready = (len(all_syms) >= 1 and final_loc != "");
            return ConversationStateUpdate(
                extracted_symptoms=all_syms,
                follow_up_question=llm_result.follow_up_question,
                enough_for_diagnosis=ready,
                location=final_loc if final_loc != "" else None,
                insurance=llm_result.insurance if llm_result.insurance else rule_ins if rule_ins else None,
                duration=llm_result.duration if llm_result.duration else rule_dur if rule_dur else None,
                severity=llm_result.severity if llm_result.severity else rule_sev if rule_sev else None
            );
        } except Exception as e {
            0;
        }
    }

    missing: list[str] = [];
    if not merged_loc or merged_loc == "" { missing.append("location (city and state)"); }
    if not merged_symptoms { missing.append("a description of your symptoms"); }

    follow_up = "";
    if missing { follow_up = "Could you share your " + missing[0] + "?"; }
    ready = (len(merged_symptoms) >= 1 and merged_loc != "");

    return ConversationStateUpdate(
        extracted_symptoms=merged_symptoms,
        follow_up_question=follow_up,
        enough_for_diagnosis=ready,
        location=merged_loc if merged_loc != "" else None,
        insurance=rule_ins if rule_ins != "" else None,
        duration=rule_dur if rule_dur != "" else None,
        severity=rule_sev if rule_sev != "" else None
    );
}
