"""Mock provider directory — telehealth fallback when NPI registry returns no results."""

import from models.provider { ProviderOption }

def get_mock_provider_directory() -> list[ProviderOption] {
    return [
        ProviderOption(
            name="TeleHealth MD",
            specialty="General Practice",
            address="Online — nationwide",
            phone="888-555-0001",
            accepts_insurance=["Aetna", "Blue Cross Blue Shield", "Cigna", "UnitedHealthcare", "Humana"],
            distance_miles=0.0,
            rating=4.3,
            accepting_new_patients=True,
            telehealth_available=True,
            notes="Same-day appointments. No location required."
        ),
        ProviderOption(
            name="Mindful Telehealth",
            specialty="Psychiatry",
            address="Online — nationwide",
            phone="888-555-0002",
            accepts_insurance=["Aetna", "Cigna", "Blue Cross Blue Shield", "UnitedHealthcare"],
            distance_miles=0.0,
            rating=4.6,
            accepting_new_patients=True,
            telehealth_available=True,
            notes="Therapy and psychiatry. Crisis lines available 24/7."
        )
    ];
}
