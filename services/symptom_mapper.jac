"""Keyword-to-ICD mapping with optional LLM enrichment."""

import from os { getenv }
import from models.codes { DiagnosisCode }
import from models.session { DiagnosisResult }
import from data.icd_codes { get_icd_code_library }

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
