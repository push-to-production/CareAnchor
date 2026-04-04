"""Healthcare provider option value object."""

obj ProviderOption {
    has name: str;
    has specialty: str;
    has address: str;
    has phone: str;
    has accepts_insurance: list[str];
    has distance_miles: float = 0.0;
    has rating: float = 0.0;
    has accepting_new_patients: bool = True;
    has telehealth_available: bool = False;
    has notes: str = "";
}
