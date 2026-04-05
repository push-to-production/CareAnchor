"""ICD-10-CM code subset for Care Anchor demo."""

import from models.codes { DiagnosisCode }

# TODO 
def get_icd_code_library() -> list[DiagnosisCode] {
    return [
        DiagnosisCode(code="R42", description="Dizziness and giddiness", category="Symptoms", confidence=0.0, source="library"),
        DiagnosisCode(code="I10", description="Essential (primary) hypertension", category="Circulatory", confidence=0.0, source="library"),
        DiagnosisCode(code="R11.0", description="Nausea", category="Symptoms", confidence=0.0, source="library"),
        DiagnosisCode(code="R10.9", description="Unspecified abdominal pain", category="Symptoms", confidence=0.0, source="library"),
        DiagnosisCode(code="R51.9", description="Headache, unspecified", category="Symptoms", confidence=0.0, source="library"),
        DiagnosisCode(code="R05.9", description="Cough, unspecified", category="Symptoms", confidence=0.0, source="library"),
        DiagnosisCode(code="R06.00", description="Dyspnea, unspecified", category="Symptoms", confidence=0.0, source="library"),
        DiagnosisCode(code="R50.9", description="Fever, unspecified", category="Symptoms", confidence=0.0, source="library"),
        DiagnosisCode(code="F32.9", description="Major depressive disorder, single episode, unspecified", category="Mental Health", confidence=0.0, source="library"),
        DiagnosisCode(code="F41.9", description="Anxiety disorder, unspecified", category="Mental Health", confidence=0.0, source="library"),
        DiagnosisCode(code="Z91.19", description="Patient's noncompliance with medical treatment", category="Factors", confidence=0.0, source="library"),
        DiagnosisCode(code="R55", description="Syncope and collapse", category="Symptoms", confidence=0.0, source="library"),
        DiagnosisCode(code="K21.0", description="Gastro-esophageal reflux disease with esophagitis", category="Digestive", confidence=0.0, source="library"),
        DiagnosisCode(code="M54.5", description="Low back pain", category="Musculoskeletal", confidence=0.0, source="library"),
        DiagnosisCode(code="R00.0", description="Tachycardia, unspecified", category="Circulatory", confidence=0.0, source="library")
    ];
}
