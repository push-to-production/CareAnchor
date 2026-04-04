"""Mock provider directory — used until a real API is wired in."""

import from models.provider { ProviderOption }

def get_mock_provider_directory() -> list[ProviderOption] {
    return [
        ProviderOption(
            name="Dr. Maria Chen",
            specialty="Internal Medicine",
            address="1200 W 6th St, Austin, TX 78703",
            phone="512-555-0101",
            accepts_insurance=["Aetna", "Blue Cross Blue Shield", "UnitedHealthcare", "Cigna"],
            distance_miles=1.2,
            rating=4.8,
            accepting_new_patients=True,
            telehealth_available=True,
            notes="Specializes in hypertension management."
        ),
        ProviderOption(
            name="Dr. James Okafor",
            specialty="Cardiology",
            address="3003 Bee Cave Rd, Austin, TX 78746",
            phone="512-555-0202",
            accepts_insurance=["Aetna", "Medicare", "UnitedHealthcare"],
            distance_miles=3.4,
            rating=4.9,
            accepting_new_patients=True,
            telehealth_available=False,
            notes="Board-certified interventional cardiologist."
        ),
        ProviderOption(
            name="Austin Family Health Clinic",
            specialty="General Practice",
            address="500 E Oltorf St, Austin, TX 78704",
            phone="512-555-0303",
            accepts_insurance=["Aetna", "Medicaid", "Blue Cross Blue Shield", "Humana", "Cigna"],
            distance_miles=2.1,
            rating=4.5,
            accepting_new_patients=True,
            telehealth_available=True,
            notes="Walk-ins welcome Mon-Fri."
        ),
        ProviderOption(
            name="Dr. Priya Nair",
            specialty="Psychiatry",
            address="701 W 38th St, Austin, TX 78705",
            phone="512-555-0404",
            accepts_insurance=["Aetna", "Cigna", "UnitedHealthcare", "Blue Cross Blue Shield"],
            distance_miles=1.8,
            rating=4.7,
            accepting_new_patients=False,
            telehealth_available=True,
            notes="Telehealth slots available within 48 hours."
        ),
        ProviderOption(
            name="Lone Star Gastroenterology",
            specialty="Gastroenterology",
            address="12201 Renfert Way, Austin, TX 78758",
            phone="512-555-0505",
            accepts_insurance=["Aetna", "Blue Cross Blue Shield", "Humana", "Medicare"],
            distance_miles=6.3,
            rating=4.6,
            accepting_new_patients=True,
            telehealth_available=False,
            notes="Accepts urgent referrals."
        ),
        ProviderOption(
            name="Dr. Rebecca Torres",
            specialty="Internal Medicine",
            address="1601 E 19th Ave, Denver, CO 80218",
            phone="303-555-0101",
            accepts_insurance=["Blue Cross Blue Shield", "Cigna", "UnitedHealthcare", "Humana"],
            distance_miles=1.0,
            rating=4.8,
            accepting_new_patients=True,
            telehealth_available=True,
            notes="Fluent in Spanish."
        ),
        ProviderOption(
            name="Mile High Cardiology",
            specialty="Cardiology",
            address="4600 Hale Pkwy, Denver, CO 80220",
            phone="303-555-0202",
            accepts_insurance=["Aetna", "UnitedHealthcare", "Medicare", "Blue Cross Blue Shield"],
            distance_miles=2.5,
            rating=4.7,
            accepting_new_patients=True,
            telehealth_available=False,
            notes="Second opinions welcome."
        ),
        ProviderOption(
            name="Denver Community Health",
            specialty="General Practice",
            address="3000 E 16th Ave, Denver, CO 80206",
            phone="303-555-0303",
            accepts_insurance=["Medicaid", "Medicare", "Blue Cross Blue Shield", "Cigna", "Humana"],
            distance_miles=0.8,
            rating=4.4,
            accepting_new_patients=True,
            telehealth_available=True,
            notes="Sliding scale fees available."
        ),
        ProviderOption(
            name="Dr. Samuel Park",
            specialty="Psychiatry",
            address="1800 Williams St, Denver, CO 80218",
            phone="303-555-0404",
            accepts_insurance=["Aetna", "Cigna", "Blue Cross Blue Shield", "UnitedHealthcare"],
            distance_miles=1.3,
            rating=4.9,
            accepting_new_patients=True,
            telehealth_available=True,
            notes="Crisis stabilization referral network."
        ),
        ProviderOption(
            name="Rocky Mountain Gastro",
            specialty="Gastroenterology",
            address="7780 E Quincy Ave, Denver, CO 80237",
            phone="303-555-0505",
            accepts_insurance=["Aetna", "Blue Cross Blue Shield", "Humana", "Medicare"],
            distance_miles=5.2,
            rating=4.5,
            accepting_new_patients=True,
            telehealth_available=False,
            notes="GI motility specialist on staff."
        ),
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
