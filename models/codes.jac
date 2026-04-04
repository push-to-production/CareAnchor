"""ICD-10-CM diagnosis code value object."""

obj DiagnosisCode {
    has code: str;
    has description: str;
    has category: str;
    has confidence: float = 0.0;
    has source: str = "symptom_mapper";
}
