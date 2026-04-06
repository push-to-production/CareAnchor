"""
ICD-10-CM code search for Care Anchor.

Backed by a BM25 inverted index over all 74 719 codes from the CMS
April 2026 release.  The index is built once and cached on disk so
subsequent imports are near-instant (~30 ms).

Public surface
--------------
search_icd_by_text(query, top_k)  -- RAG full-text search -> list[DiagnosisCode]
lookup_icd_code(code)              -- exact code lookup   -> DiagnosisCode | None
get_icd_code_library()             -- curated starter set -> list[DiagnosisCode]
"""

import from models.codes { DiagnosisCode }

# Jac-typed Python helpers (return list[list[str]] so Jac's type-checker
# sees concrete str types everywhere - no `any` gymnastics required).
import from data.icd_rag {
    search_icd_jac,
    lookup_icd_jac,
    warm_up
}

# Pre-warm the BM25 index at module load (builds cache on first run,
# ~280 ms; subsequent loads from pickle ~30 ms).
glob _icd_ready: int = warm_up();

# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

"""Full-text RAG search over all 74 K ICD-10-CM codes using BM25 ranking.
Returns up to top_k results ordered by relevance with confidence in [0,1]."""
def search_icd_by_text(query: str, top_k: int = 10) -> list[DiagnosisCode] {
    raw: list[list[str]] = search_icd_jac(query, top_k);
    results: list[DiagnosisCode] = [];
    for item in raw {
        results.append(DiagnosisCode(
            code=item[0],
            description=item[1],
            category=item[2],
            confidence=float(item[3]),
            source="rag_bm25"
        ));
    }
    return results;
}

"""Return a DiagnosisCode for an exact ICD-10-CM code, or None if not found."""
def lookup_icd_code(code: str) -> DiagnosisCode | None {
    parts: list[str] = lookup_icd_jac(code);
    if not parts {
        return None;
    }
    return DiagnosisCode(
        code=parts[0],
        description=parts[1],
        category=parts[2],
        confidence=1.0,
        source="exact_lookup"
    );
}

# ---------------------------------------------------------------------------
# Curated starter library (backward-compat with symptom_mapper)
# Descriptions and categories resolved live from the 74 K dataset.
# ---------------------------------------------------------------------------

glob _STARTER_CODES: list[str] = [
    "R42",     # Dizziness and giddiness
    "I10",     # Essential (primary) hypertension
    "R11.0",   # Nausea
    "R10.9",   # Unspecified abdominal pain
    "R51.9",   # Headache, unspecified
    "R05.9",   # Cough, unspecified
    "R06.00",  # Dyspnea, unspecified
    "R50.9",   # Fever, unspecified
    "F32.9",   # Major depressive disorder, single episode, unspecified
    "F41.9",   # Anxiety disorder, unspecified
    "Z91199",  # Patient's noncompliance with medical treatment (2026)
    "R55",     # Syncope and collapse
    "K2100",   # GERD with esophagitis, without bleeding (2026)
    "M5450",   # Low back pain, unspecified (2026)
    "R00.0",   # Tachycardia, unspecified
];

"""Return a curated set of common ICD-10-CM codes resolved from the live
74 K dataset so descriptions and categories are always accurate."""
def get_icd_code_library() -> list[DiagnosisCode] {
    library: list[DiagnosisCode] = [];
    for code in _STARTER_CODES {
        resolved = lookup_icd_code(code);
        if resolved {
            library.append(resolved);
        }
    }
    return library;
}
