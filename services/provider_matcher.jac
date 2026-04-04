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
        if len(kw) > 2 and kw in addr_lower { return True; }
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
