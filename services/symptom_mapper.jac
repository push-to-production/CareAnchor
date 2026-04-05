"""
Symptom-to-ICD mapping with RAG retrieval and optional LLM enrichment.

Pipeline
--------
1. RAG search  - BM25 over 74 K ICD-10-CM codes (fast, no LLM required)
2. Keyword gate - original hand-crafted keyword map for high-precision rules
3. LLM enrich  - optional re-ranking / narrative via byllm
"""

import from os { getenv }
import from models.codes { DiagnosisCode }
import from models.session { DiagnosisResult }
import from data.icd_codes { get_icd_code_library, search_icd_by_text, lookup_icd_code }

glob LLM_READY: bool = True;

# ---------------------------------------------------------------------------
# Hand-crafted keyword rules (fast, high-precision for the demo set)
# ---------------------------------------------------------------------------

glob SYMPTOM_KEYWORD_MAP: dict[str, list[str]] = {
    "R42":   ["dizzy", "dizziness", "lightheaded", "vertigo", "spinning"],
    "I10":   ["blood pressure", "hypertension", "hypertensive", "bp pill", "bp medication"],
    "R11.0": ["nausea", "nauseated", "nauseous", "queasy"],
    "R10.9": ["stomach pain", "abdominal pain", "belly ache", "stomach ache", "cramps"],
    "R51.9": ["headache", "head pain", "head hurts"],
    "G43.909":["migraine", "migraines", "migraine headache", "hemiplegic migraine"],
    "R05.9": ["cough", "coughing", "dry cough", "wet cough"],
    "R06.00":["shortness of breath", "cant breathe", "can not breathe", "breathless", "dyspnea"],
    "R50.9": ["fever", "temperature", "chills", "sweating", "sweats"],
    "F32.9": ["depressed", "depression", "sad", "hopeless", "worthless"],
    "F41.9": ["anxiety", "anxious", "panic attack", "worried", "nervous"],
    "F90.9": ["adhd", "attention deficit", "hyperactivity", "trouble focusing", "difficulty focusing",
              "cant focus", "can't focus", "inattentive", "impulsive", "impulsivity",
              "cant sit still", "can't sit still", "attention span", "constantly distracted",
              "trouble concentrating", "difficulty concentrating"],
    "Z91199":["missed medication", "missed pill", "skipped dose", "forgot my medicine"],
    "R55":   ["fainted", "fainting", "passed out", "blacked out", "syncope"],
    "K2100": ["heartburn", "acid reflux", "gerd", "indigestion", "burning chest"],
    "M5450": ["back pain", "lower back", "spine", "lumbar"],
    "R00.0": ["heart racing", "heart pounding", "palpitations", "fast heartbeat", "tachycardia"]
};

# ---------------------------------------------------------------------------
# Specialty routing
# ---------------------------------------------------------------------------

glob CATEGORY_SPECIALTY_MAP: dict[str, str] = {
    "Circulatory":           "Cardiology",
    "Mental Health":         "Psychiatry",
    "Digestive":             "Gastroenterology",
    "Respiratory":           "Pulmonology",
    "Musculoskeletal":       "Orthopedics",
    "Nervous System":        "Neurology",
    "Endocrine / Metabolic": "Endocrinology",
    "Genitourinary":         "Urology",
    "Sensory Organs":        "Ophthalmology / ENT",
    "Skin":                  "Dermatology",
    "Neoplasms":             "Oncology",
    "Infectious Diseases":   "Infectious Disease"
};

def _specialty_for_category(category: str) -> str {
    for key in CATEGORY_SPECIALTY_MAP {
        if key in category {
            return CATEGORY_SPECIALTY_MAP[key];
        }
    }
    return "Internal Medicine";
}

# ---------------------------------------------------------------------------
# Step 1 - keyword gate
# ---------------------------------------------------------------------------

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
    matched_codes = extract_symptom_keywords(symptom_text);
    results: list[DiagnosisCode] = [];
    for code in matched_codes {
        resolved = lookup_icd_code(code);
        if resolved {
            results.append(DiagnosisCode(
                code=resolved.code,
                description=resolved.description,
                category=resolved.category,
                confidence=0.80,
                source="keyword_rule"
            ));
        }
    }
    return results;
}

# ---------------------------------------------------------------------------
# Step 2 - RAG search (covers everything the keyword map misses)
# ---------------------------------------------------------------------------

"""BM25 search over the full 74 K ICD dataset.
Returns up to top_k ranked DiagnosisCode objects."""
def codes_from_rag(symptom_text: str, top_k: int = 8) -> list[DiagnosisCode] {
    return search_icd_by_text(symptom_text, top_k);
}

# ---------------------------------------------------------------------------
# Step 3 - merge keyword + RAG results, de-duplicate
# ---------------------------------------------------------------------------

def merge_codes(
    keyword_codes: list[DiagnosisCode],
    rag_codes: list[DiagnosisCode]
) -> list[DiagnosisCode] {
    seen: dict[str, DiagnosisCode] = {};

    # Keyword codes take priority (high precision)
    for c in keyword_codes {
        seen[c.code] = c;
    }

    # RAG codes fill in everything else; boost confidence if already seen
    for c in rag_codes {
        if c.code in seen {
            existing = seen[c.code];
            boosted: float = existing.confidence + 0.10;
            if boosted > 1.0 { boosted = 1.0; }
            seen[c.code] = DiagnosisCode(
                code=existing.code,
                description=existing.description,
                category=existing.category,
                confidence=boosted,
                source="keyword_rule+rag"
            );
        } else {
            seen[c.code] = c;
        }
    }

    # Collect values from the dict and sort by confidence descending
    merged: list[DiagnosisCode] = [];
    for code_key in seen {
        merged.append(seen[code_key]);
    }

    # Insertion sort by confidence (descending) - avoids lambda type issues
    i: int = 1;
    while i < len(merged) {
        current = merged[i];
        j: int = i - 1;
        while j >= 0 and merged[j].confidence < current.confidence {
            merged[j + 1] = merged[j];
            j -= 1;
        }
        merged[j + 1] = current;
        i += 1;
    }

    return merged;
}

# ---------------------------------------------------------------------------
# Step 4 - LLM enrichment
# ---------------------------------------------------------------------------

"""You are a clinical coding assistant. You will receive a symptom description and a candidate list of ICD-10-CM codes.
Your task: select the 2-3 codes from the candidate list that BEST match the patient's PRIMARY complaints.
STRICT RULES:
1. Only use codes that appear in the provided candidate_codes list. Do NOT invent or add any new codes.
2. Exclude symptom-only codes (R-, Y-, Z- prefixes) when a specific diagnosis code (F-, G-, I-, J-, K-, M- etc.) is available.
3. Assign confidence 0.0-1.0. Only include codes with confidence >= 0.6.
4. Return at most 3 codes in symptom_codes.
Return a complete DiagnosisResult object."""
def llm_enrich_diagnosis(
    symptom_text: str,
    candidate_codes: list[DiagnosisCode],
    inferred_specialties: list[str]
) -> DiagnosisResult by llm();

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def build_diagnosis_result(
    symptom_list: list[str],
    all_transcript_text: str
) -> DiagnosisResult {
    combined = " ".join(symptom_list) + " " + all_transcript_text;

    # --- retrieval ---
    keyword_codes = codes_from_keywords(combined);
    rag_codes      = codes_from_rag(combined, top_k=3);
    merged         = merge_codes(keyword_codes, rag_codes);

    # Cap to top 3 results to avoid over-coding
    if len(merged) > 3 { merged = merged[:3]; }

    # --- specialty inference ---
    specialties: list[str] = [];
    for c in merged {
        sp = _specialty_for_category(c.category);
        if sp not in specialties {
            specialties.append(sp);
        }
    }
    if not specialties { specialties.append("General Practice"); }

    # --- LLM enrichment (optional) ---
    if LLM_READY and merged {
        try {
            result = llm_enrich_diagnosis(combined, merged, specialties);
            # Validate: keep only codes that exist in our merged candidates
            valid_codes = [c.code for c in merged];
            filtered: list = [];
            for c in result.symptom_codes {
                code_val = c.code if hasattr(c, "code") else c.get("code", "");
                if code_val in valid_codes { filtered.append(c); }
            }
            if filtered {
                result.symptom_codes = filtered;
                return result;
            }
            # LLM returned no valid codes — fall through to rule-based
        } except Exception as e {
            0;  # fall through to rule-based result
        }
    }

    query_terms: list[str] = [];
    for c in merged { query_terms.append(c.description); }

    return DiagnosisResult(
        symptom_codes=merged,
        inferred_specialties=specialties,
        provider_query_terms=query_terms,
        narrative_reasoning="Based on reported symptoms, the following conditions may be relevant. This is not a diagnosis.",
        confidence_note="RAG + keyword match (LLM enrichment not available)."
    );
}
