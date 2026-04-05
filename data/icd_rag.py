"""
ICD-10-CM search engine.

Prefers dense vector retrieval when optional ML dependencies are installed,
and falls back to lexical ranking when they are not.

Data sources
------------
1. CMS ICD-10-CM 2026 release  — 74 719 codes + descriptions (local file)
2. QuyenAnhDE/Diseases_Symptoms — 400 disease-symptom rows (downloaded once,
   cached in .symptom_dataset.csv next to this file)
   https://huggingface.co/datasets/QuyenAnhDE/Diseases_Symptoms

Index build (first run, ~60-90 s on CPU)
-----------------------------------------
  a. Parse ICD-10 codes.
  b. Download symptom dataset; match each disease name to an ICD code.
  c. Create enriched doc per code:
       "{code}: {icd_description}. Symptoms: {symptom_list}"
  d. Encode all docs with all-MiniLM-L6-v2  (384-dim float32).
  e. Pickle: numpy matrix + metadata list → .icd_semantic_index.pkl

Subsequent runs: load pickle (~1-2 s).

Public API (unchanged from original icd_rag.py)
-----------------------------------------------
  search_icd_jac(query, top_k=10)  → list[list[str]]
  lookup_icd_jac(code)             → list[str]
  warm_up()                        → int
"""
from __future__ import annotations

import csv
import io
import os
import pickle
import re
import ssl
import urllib.request
from pathlib import Path
from typing import Optional

try:
    import numpy as np
except ModuleNotFoundError:
    np = None

try:
    from sentence_transformers import SentenceTransformer
except ModuleNotFoundError:
    SentenceTransformer = None

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

_DATA_DIR = Path(__file__).parent
_ICD_FILE = _DATA_DIR / "icd10cm_codes_2026.txt"
_SYMPTOM_CACHE = _DATA_DIR / ".symptom_dataset.csv"
_INDEX_CACHE = _DATA_DIR / ".icd_semantic_index.pkl"

# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------

_MODEL_NAME = "all-MiniLM-L6-v2"
_MODEL: Optional[SentenceTransformer] = None
_SEMANTIC_SEARCH_ENABLED = np is not None and SentenceTransformer is not None

def _get_model() -> SentenceTransformer:
    if not _SEMANTIC_SEARCH_ENABLED or SentenceTransformer is None:
        raise RuntimeError(
            "Semantic ICD search requires optional Python dependencies "
            "`numpy` and `sentence-transformers`."
        )
    global _MODEL
    if _MODEL is None:
        _MODEL = SentenceTransformer(_MODEL_NAME)
    return _MODEL

# ---------------------------------------------------------------------------
# ICD chapter → category
# ---------------------------------------------------------------------------

_CHAPTER_MAP: list[tuple[str, str, str]] = [
    ("A", "B", "Infectious Diseases"),
    ("C", "C", "Neoplasms"),
    ("D", "D", "Neoplasms / Blood Disorders"),
    ("E", "E", "Endocrine / Metabolic"),
    ("F", "F", "Mental Health"),
    ("G", "G", "Nervous System"),
    ("H", "H", "Sensory Organs"),
    ("I", "I", "Circulatory"),
    ("J", "J", "Respiratory"),
    ("K", "K", "Digestive"),
    ("L", "L", "Skin"),
    ("M", "M", "Musculoskeletal"),
    ("N", "N", "Genitourinary"),
    ("O", "O", "Pregnancy / Childbirth"),
    ("P", "P", "Perinatal"),
    ("Q", "Q", "Congenital"),
    ("R", "R", "Symptoms / Signs"),
    ("S", "T", "Injury / Poisoning"),
    ("V", "Y", "External Causes"),
    ("Z", "Z", "Factors Influencing Health"),
]

def _get_category(code: str) -> str:
    if not code:
        return "Other"
    ch = code[0].upper()
    for start, end, label in _CHAPTER_MAP:
        if start <= ch <= end:
            return label
    return "Other"

# ---------------------------------------------------------------------------
# Code formatting helpers
# ---------------------------------------------------------------------------

def _normalize_code(code: str) -> str:
    """Remove dots: R06.00 → R0600"""
    return code.replace(".", "")

def _format_code(raw_code: str) -> str:
    """Insert standard dot: R0600 → R06.00"""
    if len(raw_code) > 3:
        return raw_code[:3] + "." + raw_code[3:]
    return raw_code

# ---------------------------------------------------------------------------
# ICD-10 code parsing
# ---------------------------------------------------------------------------

def _parse_icd_codes() -> dict[str, str]:
    """Parse icd10cm_codes_2026.txt → {raw_code: description}."""
    if not _ICD_FILE.exists():
        raise FileNotFoundError(
            f"ICD-10-CM data file not found: {_ICD_FILE}\n"
            "Download from https://www.cms.gov/files/zip/"
            "april-1-2026-code-descriptions-tabular-order.zip"
        )
    codes: dict[str, str] = {}
    with open(_ICD_FILE, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split(None, 1)
            if len(parts) == 2:
                codes[parts[0]] = parts[1]
    return codes

# ---------------------------------------------------------------------------
# Symptom dataset download
# ---------------------------------------------------------------------------

_SYMPTOM_URL = (
    "https://huggingface.co/datasets/QuyenAnhDE/Diseases_Symptoms"
    "/resolve/main/Diseases_Symptoms.csv"
)

def _download_symptom_dataset() -> list[dict[str, str]]:
    """Download and cache the disease-symptom dataset."""
    if _SYMPTOM_CACHE.exists():
        with open(_SYMPTOM_CACHE, "r", encoding="utf-8") as fh:
            return list(csv.DictReader(fh))

    print("Downloading disease-symptom dataset …")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    with urllib.request.urlopen(_SYMPTOM_URL, timeout=30, context=ctx) as resp:
        data = resp.read().decode("utf-8")

    _SYMPTOM_CACHE.write_text(data, encoding="utf-8")
    return list(csv.DictReader(io.StringIO(data)))

# ---------------------------------------------------------------------------
# Disease name → ICD code mapping
# ---------------------------------------------------------------------------

# Hardcoded high-confidence mappings for common conditions
_DISEASE_ICD_SEED: dict[str, str] = {
    # Mental health
    "panic disorder":                           "F41.0",
    "generalized anxiety disorder":             "F41.1",
    "anxiety":                                  "F41.9",
    "anxiety disorder":                         "F41.9",
    "depression":                               "F32.9",
    "major depressive disorder":                "F32.9",
    "bipolar disorder":                         "F31.9",
    "adhd":                                     "F90.9",
    "attention deficit hyperactivity disorder": "F90.9",
    "schizophrenia":                            "F20.9",
    "ocd":                                      "F42.9",
    "obsessive-compulsive disorder":            "F42.9",
    "ptsd":                                     "F43.10",
    "post-traumatic stress disorder":           "F43.10",
    "anorexia nervosa":                         "F50.01",
    "bulimia nervosa":                          "F50.2",
    "binge eating disorder":                    "F50.81",
    "insomnia":                                 "G47.00",
    # Neurological
    "migraine":                                 "G43.909",
    "epilepsy":                                 "G40.909",
    "parkinson's disease":                      "G20",
    "alzheimer's disease":                      "G30.9",
    "multiple sclerosis":                       "G35",
    "transient ischemic attack":                "G45.9",
    "vertigo":                                  "H81.49",
    "benign paroxysmal positional vertigo":     "H81.10",
    "(vertigo) paroymsal  positional vertigo":  "H81.10",
    # Cardiovascular
    "hypertension":                             "I10",
    "heart attack":                             "I21.9",
    "myocardial infarction":                    "I21.9",
    "heart failure":                            "I50.9",
    "atrial fibrillation":                      "I48.91",
    "varicose veins":                           "I83.90",
    "deep vein thrombosis":                     "I82.409",
    # Respiratory
    "asthma":                                   "J45.909",
    "bronchial asthma":                         "J45.909",
    "pneumonia":                                "J18.9",
    "copd":                                     "J44.9",
    "chronic obstructive pulmonary disease":    "J44.9",
    "common cold":                              "J00",
    "influenza":                                "J11.1",
    # Digestive
    "gerd":                                     "K21.0",
    "gastroesophageal reflux disease":          "K21.0",
    "peptic ulcer disease":                     "K27.9",
    "peptic ulcer diseae":                      "K27.9",
    "irritable bowel syndrome":                 "K58.9",
    "crohn's disease":                          "K50.90",
    "ulcerative colitis":                       "K51.90",
    "gastroenteritis":                          "A09",
    "alcoholic hepatitis":                      "K70.10",
    "chronic cholestasis":                      "K74.3",
    "dimorphic hemmorhoids(piles)":             "K64.9",
    "dimorphic hemorrhoids":                    "K64.9",
    # Endocrine / Metabolic
    "diabetes":                                 "E11.9",
    "type 2 diabetes mellitus":                 "E11.9",
    "gestational diabetes":                     "O24.419",
    "hypothyroidism":                           "E03.9",
    "hyperthyroidism":                          "E05.90",
    "hypoglycemia":                             "E16.0",
    "obesity":                                  "E66.9",
    # Musculoskeletal
    "osteoarthritis":                           "M19.90",
    "arthritis":                                "M06.9",
    "rheumatoid arthritis":                     "M06.9",
    "fibromyalgia":                             "M79.3",
    "back pain":                                "M54.5",
    "low back pain":                            "M54.5",
    "cervical spondylosis":                     "M47.812",
    "rotator cuff injury":                      "M75.100",
    "fracture":                                 "S72.001A",
    # Infectious
    "aids":                                     "B20",
    "tuberculosis":                             "A15.9",
    "malaria":                                  "B54",
    "dengue":                                   "A90",
    "typhoid":                                  "A01.00",
    "chicken pox":                              "B01.9",
    "chickenpox":                               "B01.9",
    "hepatitis a":                              "B15.9",
    "hepatitis b":                              "B16.9",
    "hepatitis c":                              "B17.10",
    "hepatitis d":                              "B17.0",
    "hepatitis e":                              "B17.2",
    "fungal infection":                         "B35.4",
    "cellulitis":                               "L03.90",
    "impetigo":                                 "L01.00",
    # Genitourinary
    "urinary tract infection":                  "N39.0",
    "pyelonephritis":                           "N10",
    # Skin
    "acne":                                     "L70.0",
    "psoriasis":                                "L40.9",
    "allergy":                                  "L50.9",
    "drug reaction":                            "T88.7XXA",
    # Eye
    "open-angle glaucoma":                      "H40.10X0",
    "angle-closure glaucoma":                   "H40.20X0",
    "glaucoma":                                 "H40.9",
    # Pregnancy
    "preeclampsia":                             "O14.90",
    "gestational hypertension":                 "O13.9",
    "pregnancy-induced hypertension":           "O13.9",
    # Symptoms (for datasets that list symptom clusters as "diseases")
    "jaundice":                                 "R17",
    "paralysis (brain hemorrhage)":             "I61.9",
    "chronic fatigue syndrome":                 "R53.82",
    "complex regional pain syndrome (crps)":    "G90.50",
    "neuropathic pain":                         "G89.29",
    "chronic migraine":                         "G43.709",
    "myofascial pain syndrome":                 "M79.18",
    "sjögren's syndrome":                       "M35.00",
    "pica":                                     "F50.89",
    "fibromyalgia":                             "M79.3",
    "osteochondrosis":                          "M93.90",
    "mumps":                                    "B26.9",
    "abscess":                                  "L02.91",
}


def _auto_map_disease_to_icd(disease_name: str, icd_codes: dict[str, str]) -> str | None:
    """
    Find the best-matching ICD code for a disease name.
    1. Check hardcoded seed map (exact, lowercased).
    2. Substring search in ICD descriptions.
    Returns the raw ICD code string or None.
    """
    key = disease_name.lower().strip()
    if key in _DISEASE_ICD_SEED:
        raw = _normalize_code(_DISEASE_ICD_SEED[key])
        # Resolve via prefix if needed
        if raw in icd_codes:
            return raw
        for c in icd_codes:
            if c.startswith(raw):
                return c
        return None

    # Substring search in ICD descriptions (case-insensitive)
    lower_name = key
    # Remove parenthetical suffixes like "-1", "-2"
    lower_name = re.sub(r"\s*-\d+$", "", lower_name).strip()
    best_code: str | None = None
    for raw_code, desc in icd_codes.items():
        if lower_name in desc.lower():
            best_code = raw_code
            break

    # Try individual significant words (skip short/common ones)
    if best_code is None:
        words = [w for w in lower_name.split() if len(w) > 4]
        if words:
            from collections import Counter
            match_counts: Counter = Counter()
            for raw_code, desc in icd_codes.items():
                d = desc.lower()
                count = sum(1 for w in words if w in d)
                if count > 0:
                    match_counts[raw_code] = count
            if match_counts:
                best_code = match_counts.most_common(1)[0][0]

    return best_code

# ---------------------------------------------------------------------------
# Enriched document builder
# ---------------------------------------------------------------------------

def _build_enriched_docs(
    icd_codes: dict[str, str],
    symptom_rows: list[dict[str, str]],
) -> tuple[list[str], list[str]]:
    """
    Build the text documents and their corresponding ICD codes for encoding.

    Returns (documents, raw_codes):
      - documents[i] is the text to encode
      - raw_codes[i] is the dotless ICD code it represents
    """
    # Map ICD code → extra symptom text from the dataset
    extra_symptoms: dict[str, str] = {}
    for row in symptom_rows:
        disease_name = row.get("Name", "").strip()
        symptoms = row.get("Symptoms", "").strip()
        if not disease_name or not symptoms:
            continue
        icd_raw = _auto_map_disease_to_icd(disease_name, icd_codes)
        if icd_raw and icd_raw not in extra_symptoms:
            extra_symptoms[icd_raw] = symptoms

    documents: list[str] = []
    raw_codes: list[str] = []

    for raw_code, desc in icd_codes.items():
        symptom_suffix = ""
        if raw_code in extra_symptoms:
            symptom_suffix = f". Patient symptoms include: {extra_symptoms[raw_code]}"
        text = f"{_format_code(raw_code)}: {desc}{symptom_suffix}"
        documents.append(text)
        raw_codes.append(raw_code)

    return documents, raw_codes

# ---------------------------------------------------------------------------
# Index — build and cache
# ---------------------------------------------------------------------------

class _SemanticIndex:
    __slots__ = ("embeddings", "raw_codes", "icd_codes", "semantic_enabled")

    def __init__(
        self,
        embeddings: np.ndarray | None,
        raw_codes: list[str],
        icd_codes: dict[str, str],
        semantic_enabled: bool,
    ):
        self.embeddings = embeddings      # float32, shape (N, 384), L2-normalised
        self.raw_codes = raw_codes        # length N, parallel to embeddings
        self.icd_codes = icd_codes        # raw_code → description
        self.semantic_enabled = semantic_enabled


_INDEX: _SemanticIndex | None = None


def _build_fallback_index() -> _SemanticIndex:
    """Load ICD metadata for exact lookups and lexical search only."""
    icd_codes = _parse_icd_codes()
    return _SemanticIndex(
        embeddings=None,
        raw_codes=list(icd_codes.keys()),
        icd_codes=icd_codes,
        semantic_enabled=False,
    )


def _build_index() -> _SemanticIndex:
    """Build and persist the semantic index (one-time, ~60-90 s on CPU)."""
    if not _SEMANTIC_SEARCH_ENABLED:
        return _build_fallback_index()

    print("Building ICD semantic index — this happens once …")

    icd_codes = _parse_icd_codes()
    print(f"  Loaded {len(icd_codes):,} ICD-10-CM codes.")

    symptom_rows = _download_symptom_dataset()
    print(f"  Loaded {len(symptom_rows)} disease-symptom rows.")

    documents, raw_codes = _build_enriched_docs(icd_codes, symptom_rows)
    enriched_count = sum(1 for d in documents if "symptoms include" in d)
    print(f"  Built {len(documents):,} enriched documents ({enriched_count} with symptom data).")

    model = _get_model()
    print(f"  Encoding with {_MODEL_NAME} …")
    embeddings = model.encode(
        documents,
        batch_size=512,
        show_progress_bar=True,
        convert_to_numpy=True,
        normalize_embeddings=True,   # L2-norm → cosine sim = dot product
    )

    index = _SemanticIndex(
        embeddings=embeddings.astype(np.float32),
        raw_codes=raw_codes,
        icd_codes=icd_codes,
        semantic_enabled=True,
    )

    with open(_INDEX_CACHE, "wb") as fh:
        pickle.dump(index, fh, protocol=pickle.HIGHEST_PROTOCOL)
    print("  Semantic index saved.")
    return index


def _get_index() -> _SemanticIndex:
    global _INDEX
    if _INDEX is not None:
        return _INDEX

    if not _SEMANTIC_SEARCH_ENABLED:
        _INDEX = _build_fallback_index()
        return _INDEX

    if _INDEX_CACHE.exists():
        try:
            with open(_INDEX_CACHE, "rb") as fh:
                _INDEX = pickle.load(fh)
            return _INDEX
        except Exception:
            pass  # corrupt cache — rebuild

    _INDEX = _build_index()
    return _INDEX

# ---------------------------------------------------------------------------
# Cosine similarity search
# ---------------------------------------------------------------------------

_TOKEN_RE = re.compile(r"[a-z0-9]+")


def _tokenize(text: str) -> list[str]:
    return _TOKEN_RE.findall(text.lower())


def _lexical_search(
    query: str,
    top_k: int,
    index: _SemanticIndex,
) -> list[tuple[str, float]]:
    """Fallback ranking when semantic dependencies are unavailable."""
    query = query.strip()
    if not query:
        return []

    query_text = query.lower()
    query_tokens = _tokenize(query)
    if not query_tokens:
        query_tokens = [query_text]
    normalized_code = _normalize_code(query.upper())

    scored: list[tuple[str, float]] = []
    for raw_code, desc in index.icd_codes.items():
        display_code = _format_code(raw_code).lower()
        haystack = f"{display_code} {raw_code.lower()} {desc.lower()} {_get_category(raw_code).lower()}"

        code_exact = 1.0 if normalized_code == raw_code else 0.0
        code_prefix = 1.0 if normalized_code and raw_code.startswith(normalized_code) else 0.0
        phrase_match = 1.0 if query_text in haystack else 0.0
        token_hits = sum(1 for token in query_tokens if token in haystack)

        if code_exact == 0.0 and code_prefix == 0.0 and phrase_match == 0.0 and token_hits == 0:
            continue

        coverage = token_hits / max(len(query_tokens), 1)
        score = min(
            0.99,
            0.15 + (0.45 * coverage) + (0.20 * phrase_match) + (0.20 * code_prefix) + (0.44 * code_exact),
        )
        scored.append((raw_code, score))

    scored.sort(key=lambda item: (-item[1], item[0]))
    return scored[:top_k]


def _semantic_search(
    query: str,
    top_k: int,
    index: _SemanticIndex,
) -> list[tuple[str, float]]:
    """
    Encode query and return top_k (raw_code, normalised_score) pairs.
    Scores are in [0, 1] (cosine similarity normalised to [0, 1]).
    """
    if not index.semantic_enabled:
        return _lexical_search(query, top_k, index)

    model = _get_model()
    query_vec = model.encode(
        [query],
        convert_to_numpy=True,
        normalize_embeddings=True,
    )[0].astype(np.float32)                        # shape (384,)

    sims = index.embeddings @ query_vec            # shape (N,), values in [-1, 1]

    # Get indices of top-k highest scores
    if top_k >= len(sims):
        top_idx = np.argsort(sims)[::-1]
    else:
        # argpartition is O(N) then sort only top_k
        part = np.argpartition(sims, -top_k)[-top_k:]
        top_idx = part[np.argsort(sims[part])[::-1]]

    results: list[tuple[str, float]] = []
    seen_codes: set[str] = set()
    for idx in top_idx:
        code = index.raw_codes[idx]
        if code in seen_codes:
            continue
        seen_codes.add(code)
        # Normalise cosine sim from [-1,1] to [0,1]
        score = float((sims[idx] + 1.0) / 2.0)
        results.append((code, score))

    return results

# ---------------------------------------------------------------------------
# Code resolution helpers
# ---------------------------------------------------------------------------

def _resolve_code(code: str, icd_codes: dict[str, str]) -> tuple[str, str] | None:
    """Accept dotted or dotless code; try exact match then prefix fallback."""
    normalized = _normalize_code(code)
    if normalized in icd_codes:
        return normalized, icd_codes[normalized]
    for stored, desc in icd_codes.items():
        if stored.startswith(normalized):
            return stored, desc
    return None

# ---------------------------------------------------------------------------
# Public Jac API
# ---------------------------------------------------------------------------

def search_icd_jac(query: str, top_k: int = 10) -> list[list[str]]:
    """
    Search over ICD-10-CM documents.

    Returns a list of [display_code, description, category, confidence_str]
    sorted by relevance descending.  Confidence is in (0, 1].
    """
    index = _get_index()
    ranked = _semantic_search(query, top_k, index)

    # Semantic scores are stricter than lexical fallback scores.
    _MIN_CONFIDENCE = 0.55 if index.semantic_enabled else 0.25

    result: list[list[str]] = []
    for raw_code, score in ranked:
        if score < _MIN_CONFIDENCE:
            break
        desc = index.icd_codes.get(raw_code, "")
        if not desc:
            continue
        result.append([
            _format_code(raw_code),
            desc,
            _get_category(raw_code),
            str(round(score, 4)),
        ])

    return result


def lookup_icd_jac(code: str) -> list[str]:
    """
    Exact lookup (with dot-normalisation and prefix fallback).
    Returns [display_code, description, category] or [].
    """
    index = _get_index()
    resolved = _resolve_code(code, index.icd_codes)
    if resolved is None:
        return []
    raw_code, desc = resolved
    return [_format_code(raw_code), desc, _get_category(raw_code)]


def warm_up() -> int:
    """Pre-load the index.  Returns total code count."""
    return len(_get_index().icd_codes)


# ---------------------------------------------------------------------------
# Legacy Python-dict API (kept for any direct Python callers)
# ---------------------------------------------------------------------------

def search_icd_codes(query: str, top_k: int = 10) -> list[dict]:
    """Python-dict variant of search_icd_jac (not called from Jac)."""
    index = _get_index()
    ranked = _semantic_search(query, top_k, index)
    result = []
    for raw_code, score in ranked:
        desc = index.icd_codes.get(raw_code, "")
        result.append({
            "code": _format_code(raw_code),
            "description": desc,
            "category": _get_category(raw_code),
            "score": round(score, 4),
        })
    return result


def get_icd_description(code: str) -> str | None:
    index = _get_index()
    resolved = _resolve_code(code, index.icd_codes)
    return resolved[1] if resolved else None


def get_icd_category(code: str) -> str:
    return _get_category(code)
