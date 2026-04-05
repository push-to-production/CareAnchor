"""Provider Ranking Agent — deterministic provider reordering with no extra model calls."""

import from models.session { UserSession, DiagnosisResult, RankedProvider }
import from models.provider { ProviderOption }

def _insurance_score(session: UserSession, provider: ProviderOption) -> float {
    if not session.insurance or session.insurance.strip() == "" { return 0.0; }
    insurance = session.insurance.lower().strip();
    for accepted in provider.accepts_insurance {
        accepted_lower = accepted.lower().strip();
        if insurance in accepted_lower or accepted_lower in insurance { return 2.0; }
    }
    return 0.0;
}

def _specialty_score(diagnosis: DiagnosisResult, provider: ProviderOption) -> float {
    if not diagnosis.inferred_specialties or len(diagnosis.inferred_specialties) == 0 { return 0.0; }
    specialty_lower = provider.specialty.lower();
    for inferred in diagnosis.inferred_specialties {
        inferred_lower = inferred.lower();
        if inferred_lower in specialty_lower or specialty_lower in inferred_lower { return 3.0; }
    }
    return 0.0;
}

def _distance_score(provider: ProviderOption) -> float {
    if provider.distance_miles <= 0.0 { return 1.0; }
    if provider.distance_miles <= 5.0 { return 2.0; }
    if provider.distance_miles <= 15.0 { return 1.0; }
    return 0.0;
}

def _availability_score(provider: ProviderOption) -> float {
    score = 0.0;
    if provider.accepting_new_patients { score += 2.0; }
    if provider.telehealth_available { score += 1.0; }
    return score;
}

def _rating_score(provider: ProviderOption) -> float {
    if provider.rating >= 4.7 { return 2.0; }
    if provider.rating >= 4.3 { return 1.5; }
    if provider.rating >= 4.0 { return 1.0; }
    return 0.0;
}

def _ranking_reasons(
    session: UserSession,
    diagnosis: DiagnosisResult,
    provider: ProviderOption
) -> list[str] {
    reasons: list[str] = [];

    if _specialty_score(diagnosis, provider) > 0.0 {
        reasons.append("Specialty aligns with inferred care need.");
    }
    if _insurance_score(session, provider) > 0.0 {
        reasons.append("Insurance match detected.");
    }
    if provider.accepting_new_patients {
        reasons.append("Accepting new patients.");
    }
    if provider.telehealth_available {
        reasons.append("Telehealth available.");
    }
    if provider.distance_miles > 0.0 and provider.distance_miles <= 15.0 {
        reasons.append("Reasonable travel distance.");
    }
    if provider.rating >= 4.3 {
        reasons.append("Strong patient rating.");
    }

    if len(reasons) == 0 {
        reasons.append("Included as fallback provider option.");
    }
    return reasons;
}

def rank_provider_options(
    session: UserSession,
    diagnosis: DiagnosisResult,
    providers: list[ProviderOption]
) -> list[RankedProvider] {
    ranked: list[RankedProvider] = [];

    for provider in providers {
        score = (
            _specialty_score(diagnosis, provider)
            + _insurance_score(session, provider)
            + _distance_score(provider)
            + _availability_score(provider)
            + _rating_score(provider)
        );
        ranked.append(
            RankedProvider(
                provider=provider,
                score=score,
                reasons=_ranking_reasons(session, diagnosis, provider)
            )
        );
    }

    ranked.sort(key=lambda item: item.score, reverse=True);
    return ranked;
}

def apply_provider_ranking(session: UserSession, diagnosis: DiagnosisResult) -> list[ProviderOption] {
    session.active_agent = "Provider Ranking Agent";
    session.agent_path.append("Provider Ranking Agent:active");

    ranked = rank_provider_options(session, diagnosis, session.provider_options);
    session.ranked_provider_options = ranked;

    ordered: list[ProviderOption] = [];
    for item in ranked {
        ordered.append(item.provider);
    }
    session.provider_options = ordered;

    session.agent_path.append("Provider Ranking Agent:completed");
    return ordered;
}
