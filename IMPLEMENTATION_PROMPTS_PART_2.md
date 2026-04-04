# Care Anchor — Implementation Prompts Part 2
## Core Services

> **Blueprint phase:** Steps 5–9 of 27  
> **Goal:** Build the deterministic and LLM-backed service layer. No walkers, no graph ops —
> pure functions only. Each file is independently testable.  
> **Prerequisite:** Part 1 complete; `models/` and `data/` layers pass `jac check`.

---

## Prompt 6 — Safety Rules Service (Deterministic Crisis Detection)

````text
You are continuing to build **Care Anchor**. Parts 1 is complete.

### Context
`services/safety_rules.jac` is the highest-priority module in the system.
It MUST be deterministic — no LLM, no network, always fast.
The intervention pipeline calls this on EVERY message before any other agent runs.

Safety constraint from the spec:
> Crisis detection MUST be deterministic keyword matching as the primary check.
> `by llm()` MAY be used as a secondary enrichment pass but must never replace the phrase list.

### File to Create: `services/safety_rules.jac`

```jac
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
```

### Verification
Run `jac check services/safety_rules.jac`. Must pass.
Write a quick mental test: `detect_crisis("I want to die")` → `is_crisis=True`. `detect_crisis("I have a headache")` → `is_crisis=False`.
````

---

## Prompt 7 — Symptom Mapper Service

````text
You are continuing to build **Care Anchor**. Parts 1–2 Prompt 6 are complete.

### Context
`services/symptom_mapper.jac` maps free-text symptoms to ICD-10-CM codes.
It uses two layers:
1. **Deterministic keyword rules** — fast, always available.
2. **`by llm()` enrichment** — adds confidence scores and catches edge cases;
   gated on `LLM_READY` so the app works without an API key.

Rules for `by llm()` from `AGENTS.md`:
- The docstring immediately before the `def` is the LLM system prompt.
- Return type must be a concrete `obj` or primitive.
- Wrap every call in `try { } except Exception as e { }` with a rule-based fallback.
- Gate on `LLM_READY`.

### File to Create: `services/symptom_mapper.jac`

```jac
"""Keyword-to-ICD mapping with optional LLM enrichment."""

import from os { getenv }
import from ..models.codes { DiagnosisCode }
import from ..models.session { DiagnosisResult }
import from ..data.icd_codes { get_icd_code_library }

glob LLM_READY: bool = (getenv("OPENAI_API_KEY") or "") != "";

glob SYMPTOM_KEYWORD_MAP: dict[str, list[str]] = {
    "R42":   ["dizzy", "dizziness", "lightheaded", "vertigo", "spinning"],
    "I10":   ["blood pressure", "hypertension", "hypertensive", "bp pill", "bp medication"],
    "R11.0": ["nausea", "nauseated", "nauseous", "queasy"],
    "R10.9": ["stomach pain", "abdominal pain", "belly ache", "stomach ache", "cramps"],
    "R51.9": ["headache", "migraine", "head pain", "head hurts"],
    "R05.9": ["cough", "coughing", "dry cough", "wet cough"],
    "R06.00":["shortness of breath", "cant breathe", "can not breathe", "breathless", "dyspnea"],
    "R50.9": ["fever", "temperature", "chills", "sweating", "sweats"],
    "F32.9": ["depressed", "depression", "sad", "hopeless", "worthless"],
    "F41.9": ["anxiety", "anxious", "panic attack", "worried", "nervous"],
    "Z91.19":["missed medication", "missed pill", "skipped dose", "forgot my medicine"],
    "R55":   ["fainted", "fainting", "passed out", "blacked out", "syncope"],
    "K21.0": ["heartburn", "acid reflux", "gerd", "indigestion", "burning chest"],
    "M54.5": ["back pain", "lower back", "spine", "lumbar"],
    "R00.0": ["heart racing", "heart pounding", "palpitations", "fast heartbeat", "tachycardia"]
};

def extract_symptom_keywords(message: str) -> list[str] {
    lower_msg = message.lower();
    found: list[str] = [];
    for code in SYMPTOM_KEYWORD_MAP {
        keywords = SYMPTOM_KEYWORD_MAP[code];
        for kw in keywords {
            if kw in lower_msg {
                if code not in found { found.append(code); }
            }
        }
    }
    return found;
}

def codes_from_keywords(symptom_text: str) -> list[DiagnosisCode] {
    library = get_icd_code_library();
    matched_codes = extract_symptom_keywords(symptom_text);
    results: list[DiagnosisCode] = [];
    for item in library {
        if item.code in matched_codes {
            results.append(DiagnosisCode(
                code=item.code,
                description=item.description,
                category=item.category,
                confidence=0.75,
                source="keyword_rule"
            ));
        }
    }
    return results;
}

"""Map the following symptom descriptions to the most appropriate ICD-10-CM codes from the
provided library. For each match, assign a confidence score between 0.0 and 1.0 based on
how precisely the symptoms map to the code. Include a brief narrative_reasoning explaining
the differential. Only include codes where confidence > 0.4.
Return a DiagnosisResult object."""
def llm_enrich_diagnosis(
    symptom_text: str,
    rule_based_codes: list[DiagnosisCode],
    inferred_specialties: list[str]
) -> DiagnosisResult by llm();

def build_diagnosis_result(
    symptom_list: list[str],
    all_transcript_text: str
) -> DiagnosisResult {
    combined = " ".join(symptom_list) + " " + all_transcript_text;
    rule_codes = codes_from_keywords(combined);
    specialties: list[str] = [];
    for c in rule_codes {
        match c.category {
            case "Circulatory": if "Cardiology" not in specialties { specialties.append("Cardiology"); }
            case "Mental Health": if "Psychiatry" not in specialties { specialties.append("Psychiatry"); }
            case "Digestive": if "Gastroenterology" not in specialties { specialties.append("Gastroenterology"); }
            case _: if "Internal Medicine" not in specialties { specialties.append("Internal Medicine"); }
        }
    }
    if not specialties { specialties.append("General Practice"); }

    if LLM_READY and rule_codes {
        try {
            return llm_enrich_diagnosis(combined, rule_codes, specialties);
        } except Exception as e {
            0;
        }
    }

    query_terms: list[str] = [];
    for c in rule_codes { query_terms.append(c.description); }

    return DiagnosisResult(
        symptom_codes=rule_codes,
        inferred_specialties=specialties,
        provider_query_terms=query_terms,
        narrative_reasoning="Based on reported symptoms, the following conditions may be relevant. This is not a diagnosis.",
        confidence_note="Rule-based match (LLM enrichment not available)."
    );
}
```

### Verification
Run `jac check services/symptom_mapper.jac`. Must pass.
````

---

## Prompt 8 — Transcript Parser Service

````text
You are continuing to build **Care Anchor**. Prompts 1–7 are complete.

### Context
`services/transcript_parser.jac` extracts structured fields (symptoms, location, insurance,
duration, severity) from free-text user messages. It uses:
1. **Regex + dictionary rules** — deterministic baseline.
2. **`by llm()` extraction** — richer NLU; gated on `LLM_READY`.

The `by llm()` docstring is the LLM system prompt. It must be specific and
instruct the model to return a `ConversationStateUpdate`.

### File to Create: `services/transcript_parser.jac`

```jac
"""Structured field extraction from free-text messages."""

import re;
import from os { getenv }
import from ..models.session { ConversationStateUpdate }
import from .common { first_non_empty, merge_strings, normalize_text, transcript_excerpt }
import from .symptom_mapper { extract_symptom_keywords, codes_from_keywords }

glob LLM_READY: bool = (getenv("OPENAI_API_KEY") or "") != "";

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
    transcript_excerpt: str,
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
            ready = (all_syms.length >= 1 and final_loc != "" and final_ins != "");
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
    ready = (merged_symptoms.length >= 1 and merged_loc != "" and merged_ins != "");

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
```

### Verification
Run `jac check services/transcript_parser.jac`. Must pass.
````

---

## Prompt 9 — Provider Matcher Service

````text
You are continuing to build **Care Anchor**. Prompts 1–8 are complete.

### Context
`services/provider_matcher.jac` filters the mock provider directory by:
1. Specialty (derived from the diagnosis result).
2. Insurance (extracted from user conversation).
3. Location (city/state keyword match).

This is deterministic — no LLM. It will be swapped for a real API later.

### File to Create: `services/provider_matcher.jac`

```jac
"""Filter mock provider directory by specialty, insurance, and location."""

import from ..models.provider { ProviderOption }
import from ..models.session { DiagnosisResult }
import from ..data.mock_providers { get_mock_provider_directory }

def normalize_insurance(raw: str) -> str {
    lower = raw.lower().strip();
    if "aetna" in lower { return "Aetna"; }
    if "blue cross" in lower or "blue shield" in lower or "bcbs" in lower { return "Blue Cross Blue Shield"; }
    if "cigna" in lower { return "Cigna"; }
    if "united" in lower or "uhc" in lower { return "UnitedHealthcare"; }
    if "humana" in lower { return "Humana"; }
    if "medicare" in lower { return "Medicare"; }
    if "medicaid" in lower { return "Medicaid"; }
    return raw;
}

def location_matches(provider_address: str, user_location: str) -> bool {
    if not user_location or user_location.strip() == "" { return True; }
    loc_lower = user_location.lower();
    addr_lower = provider_address.lower();
    if "online" in addr_lower or "nationwide" in addr_lower { return True; }
    city_keywords = loc_lower.split(",")[0].strip().split(" ");
    for kw in city_keywords {
        if kw.length > 2 and kw in addr_lower { return True; }
    }
    return False;
}

def insurance_matches(provider: ProviderOption, normalized_insurance: str) -> bool {
    if not normalized_insurance or normalized_insurance.strip() == "" { return True; }
    for ins in provider.accepts_insurance {
        if ins.lower() == normalized_insurance.lower() { return True; }
    }
    return False;
}

def specialty_matches(provider: ProviderOption, specialties: list[str]) -> bool {
    if not specialties { return True; }
    for spec in specialties {
        if spec.lower() in provider.specialty.lower() { return True; }
        if provider.specialty.lower() in spec.lower() { return True; }
    }
    return False;
}

def find_providers(
    diagnosis: DiagnosisResult,
    location: str,
    insurance: str,
    max_results: int
) -> list[ProviderOption] {
    all_providers = get_mock_provider_directory();
    normalized_ins = normalize_insurance(insurance);

    matched: list[ProviderOption] = [];
    for provider in all_providers {
        spec_ok = specialty_matches(provider, diagnosis.inferred_specialties);
        ins_ok = insurance_matches(provider, normalized_ins);
        loc_ok = location_matches(provider.address, location);
        if spec_ok and ins_ok and loc_ok {
            matched.append(provider);
        }
    }

    if not matched {
        for provider in all_providers {
            ins_ok = insurance_matches(provider, normalized_ins);
            if ins_ok and provider.telehealth_available {
                matched.append(provider);
            }
        }
    }

    if not matched {
        for provider in all_providers {
            if provider.telehealth_available { matched.append(provider); }
        }
    }

    matched.sort(key=lambda p: ProviderOption -> float : p.rating * -1.0);
    return matched[:max_results];
}
```

### Verification
Run `jac check services/provider_matcher.jac`. Must pass.
````

---

## Prompt 10 — Package Init Files for All Modules

````text
You are continuing to build **Care Anchor**. Prompts 1–9 are complete.

### Context
Jac requires `__init__.jac` in every package directory. These files enable `import from package.module { ... }`
from other parts of the project. They use full dotted paths — never bare names.

### Files to Create or Update

**`models/__init__.jac`** (update from Prompt 2):
```jac
"""Care Anchor models package."""

import from care_anchor.models.codes { DiagnosisCode }
import from care_anchor.models.provider { ProviderOption }
import from care_anchor.models.session {
    UserSession,
    ChatMessage,
    CareSummary,
    ConversationStateUpdate,
    InterventionDecision,
    DiagnosisResult,
    CallingPreparation,
    append_message,
    update_session_timestamp,
    session_to_dict
}
```

**`services/__init__.jac`** (update from Prompt 4):
```jac
"""Care Anchor services package."""

import from care_anchor.services.common {
    new_session_id, iso_now, normalize_text, first_non_empty,
    merge_strings, truncate, transcript_excerpt, APP_DISCLAIMER
}
import from care_anchor.services.safety_rules { detect_crisis, detect_resume }
import from care_anchor.services.symptom_mapper { build_diagnosis_result, extract_symptom_keywords }
import from care_anchor.services.transcript_parser { build_conversation_state_update }
import from care_anchor.services.provider_matcher { find_providers }
```

**`data/__init__.jac`** (update from Prompt 5):
```jac
"""Care Anchor data package."""

import from care_anchor.data.mock_providers { get_mock_provider_directory }
import from care_anchor.data.icd_codes { get_icd_code_library }
```

**`agents/__init__.jac`** (new — empty placeholder until Part 3):
```jac
"""Care Anchor agents package."""
```

**`components/__init__.jac`** (new — empty placeholder until Part 5):
```jac
"""Care Anchor components package."""
```

### Why this matters
In Jac, `import from care_anchor.services.common { iso_now }` requires `care_anchor/__init__.jac`
to exist and `services/__init__.jac` to exist. Without them, the runtime cannot resolve the path.
These files wire the package graph together.

### Verification
At this point, run `jac check models/session.jac` and `jac check services/provider_matcher.jac`.
Both should resolve imports cleanly. Fix any path errors before proceeding to Part 3.
````
