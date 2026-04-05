"""Provider lookup — queries NLM NPI registry API; falls back to mock data."""

import from models.provider { ProviderOption }
import from models.session { DiagnosisResult }
import from data.mock_providers { get_mock_provider_directory }
import from services.npi_lookup { search_providers_npi }

def specialty_matches(provider: ProviderOption, specialties: list[str]) -> bool {
    if not specialties { return True; }
    for spec in specialties {
        if spec.lower() in provider.specialty.lower() { return True; }
        if provider.specialty.lower() in spec.lower() { return True; }
    }
    return False;
}

def location_matches(provider_address: str, user_location: str) -> bool {
    if not user_location or user_location.strip() == "" { return True; }
    addr_lower = provider_address.lower();
    if "online" in addr_lower or "nationwide" in addr_lower { return True; }
    # Support multiple locations separated by " or ", " and ", or "/"
    # Normalize separators so we can split on a single delimiter
    normalized = user_location.lower().replace(" and ", " or ").replace("/", " or ");
    location_parts = normalized.split(" or ");
    for loc_part in location_parts {
        loc_part_stripped = loc_part.strip();
        if not loc_part_stripped { continue; }
        parts = loc_part_stripped.split(",");
        city_words = parts[0].strip().split(" ");
        for kw in city_words {
            if len(kw) > 2 and kw in addr_lower { return True; }
        }
    }
    return False;
}

def _dict_to_provider(d: dict) -> ProviderOption {
    return ProviderOption(
        name=d["name"],
        specialty=d["specialty"],
        address=d["address"],
        phone=d["phone"],
        accepts_insurance=d["accepts_insurance"],
        distance_miles=d["distance_miles"],
        rating=d["rating"],
        accepting_new_patients=d["accepting_new_patients"],
        telehealth_available=d["telehealth_available"],
        notes=d["notes"]
    );
}

def _mock_fallback(
    diagnosis: DiagnosisResult,
    location: str,
    max_results: int
) -> list[ProviderOption] {
    all_providers = get_mock_provider_directory();
    matched: list[ProviderOption] = [];
    for provider in all_providers {
        spec_ok = specialty_matches(provider, diagnosis.inferred_specialties);
        loc_ok = location_matches(provider.address, location);
        if spec_ok and loc_ok {
            matched.append(provider);
        }
    }
    if not matched {
        for provider in all_providers {
            if provider.telehealth_available { matched.append(provider); }
        }
    }
    return matched[:max_results];
}

def find_therapists(location: str, max_results: int) -> list[ProviderOption] {
    therapy_diagnosis = DiagnosisResult(
        narrative_reasoning="Crisis intervention — mental health support needed",
        confidence_note="",
        symptom_codes=[],
        inferred_specialties=["Psychiatry", "Mental Health", "Psychology", "Counseling", "Therapist"],
        provider_query_terms=["therapist", "mental health", "psychiatry", "counseling"]
    );
    return find_providers(therapy_diagnosis, location, max_results);
}

def format_therapists_markdown(providers: list[ProviderOption], location: str) -> str {
    if not providers or len(providers) == 0 {
        return "I wasn't able to find therapists in your area right now, but you can call **988** (Suicide & Crisis Lifeline) or text HOME to **741741** (Crisis Text Line) for immediate support.";
    }
    loc_label = "near " + location if location and location.strip() != "" else "(telehealth)";
    lines: list[str] = ["Here are some mental health providers " + loc_label + " who can help:\n"];
    for p in providers {
        telehealth_note = " · Telehealth available" if p.telehealth_available else "";
        lines.append("**" + p.name + "** — " + p.specialty);
        lines.append(p.address + " · " + p.phone + telehealth_note);
        lines.append("");
    }
    lines.append("You can also call or text **988** at any time for the Suicide & Crisis Lifeline.");
    return "\n".join(lines);
}

def find_providers(
    diagnosis: DiagnosisResult,
    location: str,
    max_results: int
) -> list[ProviderOption] {
    try {
        raw_results = search_providers_npi(
            specialties=diagnosis.inferred_specialties,
            location=location,
            max_results=max_results
        );
        if raw_results and len(raw_results) > 0 {
            providers: list[ProviderOption] = [];
            for d in raw_results {
                providers.append(_dict_to_provider(d));
            }
            return providers;
        }
    } except Exception as e {
        0;
    }

    return _mock_fallback(diagnosis, location, max_results);
}
