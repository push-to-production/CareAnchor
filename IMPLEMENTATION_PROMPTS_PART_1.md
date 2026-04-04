# Care Anchor — Implementation Prompts Part 1
## Bootstrap, Project Structure & Data Models

> **Blueprint phase:** Steps 1–5 of 27  
> **Goal:** Scaffold the project shell, declare all deps, and define every data shape before writing any logic.  
> **Rule:** Each prompt must pass `jac check` (or be non-Jac config) before the next prompt is started.

---

## Prompt 1 — Bootstrap Project & Configuration

````text
You are scaffolding **Care Anchor**, a full-stack medical triage and care coordination platform
built entirely in Jac using the jaseci client framework.

### Task
Create the project from scratch using the Jac CLI, then write the initial configuration files.

### Steps

1. From the parent `Hackathon/` directory, run:
   ```bash
   jac create care_anchor --use client
   cd care_anchor
   ```

2. Replace the generated `jac.toml` with exactly the following content:
   ```toml
   [project]
   name = "care_anchor"
   version = "0.1.0"
   description = "Care Anchor — AI triage and provider matching"
   entry-point = "main.jac"

   [dependencies]
   python-dotenv = ">=1.0.0"
   requests = ">=2.31.0"
   reportlab = ">=4.0.0"
   twilio = ">=9.0.0"

   [dependencies.npm]
   react = "^18.2.0"
   react-dom = "^18.2.0"
   jac-client-node = "1.0.7"

   [dependencies.npm.dev]
   vite = "^6.4.1"
   "@vitejs/plugin-react" = "^4.2.1"
   "@jac-client/dev-deps" = "2.0.0"

   [dev-dependencies]
   watchdog = ">=3.0.0"

   [serve]
   base_route_app = "app"
   port = 8000

   [plugins.client]
   port = 5173

   [plugins.byllm]
   model_name = "gpt-4o-mini"
   ```

3. Create a `.env` file in the project root (never commit this):
   ```
   OPENAI_API_KEY=sk-replace_with_your_key
   JAC_SECRET_KEY=change_me_in_production
   TWILIO_ACCOUNT_SID=AC_replace_if_needed
   TWILIO_AUTH_TOKEN=replace_if_needed
   ```

4. Create `.gitignore` entries for `.env`, `exports/`, and `.jac/`.

5. Run `jac install` to sync all Python and npm dependencies.

### Directory structure to create (empty directories with placeholder `__init__.jac`):
```
care_anchor/
├── models/
├── agents/
├── services/
├── data/
├── components/
└── styles/
```

Create each subdirectory. Do NOT write any Jac code yet — just the dirs and config files.

### Verification
- `jac install` completes without error.
- `care_anchor/` directory exists with `jac.toml` and `.env`.
````

---

## Prompt 2 — Data Models: DiagnosisCode & ProviderOption

````text
You are continuing to build **Care Anchor**. The project has been bootstrapped in Prompt 1.

### Context
These two `obj` types are simple value objects with no logic. They are imported by almost every
other file in the project, so they must be correct before anything else is written.

Reference `AGENTS.md` for language rules. Key rules relevant here:
- Non-default attributes MUST come before default attributes in the same archetype.
- Use `str | None = None` for optional strings.
- No `pass` keyword — use `{}` or a comment in empty blocks.
- `True`/`False` (capitalized) — `true`/`false` fail at runtime.

### Files to Create

**`models/codes.jac`**
```jac
"""ICD-10-CM diagnosis code value object."""

obj DiagnosisCode {
    has code: str;
    has description: str;
    has category: str;
    has confidence: float = 0.0;
    has source: str = "symptom_mapper";
}
```

**`models/provider.jac`**
```jac
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
```

**`models/__init__.jac`**
```jac
"""Care Anchor models package."""

import from care_anchor.models.codes { DiagnosisCode }
import from care_anchor.models.provider { ProviderOption }
```

### Verification
Run `jac check models/codes.jac` and `jac check models/provider.jac`. Both must pass with no errors.
````

---

## Prompt 3 — Data Model: UserSession & Value Objects

````text
You are continuing to build **Care Anchor**. Prompts 1–2 are complete.

### Context
`models/session.jac` defines the core graph node (`UserSession`) and all supporting value objects
that flow through the pipeline. This is the single most-imported file in the project.

Key rules from `AGENTS.md`:
- `node` is a graph archetype that persists when connected to `root`.
- `has` fields with no default come before fields with defaults.
- `str | None = None` is valid for optional fields.
- Lists must be initialized: `has x: list[T] = [];`
- `True`/`False` only — never `true`/`false`.

### File to Create: `models/session.jac`

```jac
"""Session graph node and supporting value objects."""

import from .codes { DiagnosisCode }
import from .provider { ProviderOption }

glob APP_DISCLAIMER: str = "Care Anchor supports care coordination. It does not replace emergency care or professional diagnosis.";

obj ChatMessage {
    has role: str;
    has content: str;
    has timestamp: str;
    has agent: str;
}

obj CareSummary {
    has summary: str;
    has location: str;
    has insurance: str;
    has transcript_excerpt: str;
    has symptom_codes: list[DiagnosisCode] = [];
    has provider_options: list[ProviderOption] = [];
    has risk_flags: list[str] = [];
    has agent_path: list[str] = [];
}

obj ConversationStateUpdate {
    has follow_up_question: str;
    has extracted_symptoms: list[str] = [];
    has enough_for_diagnosis: bool = False;
    has location: str | None = None;
    has insurance: str | None = None;
    has duration: str | None = None;
    has severity: str | None = None;
}

obj InterventionDecision {
    has is_crisis: bool;
    has reason: str;
    has urgency: str;
    has response_markdown: str;
    has can_resume_if_user_declines: bool = True;
}

obj DiagnosisResult {
    has narrative_reasoning: str;
    has confidence_note: str;
    has symptom_codes: list[DiagnosisCode] = [];
    has inferred_specialties: list[str] = [];
    has provider_query_terms: list[str] = [];
}

obj CallingPreparation {
    has normalized_location: str;
    has normalized_insurance: str;
    has provider_search_ready: bool;
    has missing_fields: list[str] = [];
    has note: str = "";
}

node UserSession {
    has session_id: str;
    has created_at: str;
    has updated_at: str;
    has active_agent: str = "Conversation Agent";
    has last_user_message: str = "";
    has transcript: list[ChatMessage] = [];
    has extracted_symptoms: list[str] = [];
    has risk_flags: list[str] = [];
    has assigned_codes: list[DiagnosisCode] = [];
    has provider_options: list[ProviderOption] = [];
    has agent_path: list[str] = [];
    has intervention_active: bool = False;
    has intervention_resolved: bool = False;
    has symptom_duration: str | None = None;
    has severity: str | None = None;
    has location: str | None = None;
    has insurance: str | None = None;
    has summary_text: str | None = None;
}
```

Also add helper functions at the bottom of the same file that the orchestrator will use:

```jac
def append_message(session: UserSession, role: str, content: str, agent: str) -> None {
    import from ..services.common { iso_now }
    msg = ChatMessage(role=role, content=content, timestamp=iso_now(), agent=agent);
    session.transcript.append(msg);
}

def update_session_timestamp(session: UserSession) -> None {
    import from ..services.common { iso_now }
    session.updated_at = iso_now();
}

def session_to_dict(session: UserSession) -> dict {
    disclaimer = APP_DISCLAIMER;
    agent_trace: list = [
        {"name": "Intervention Agent", "status": "listening"},
        {"name": "Conversation Agent", "status": "idle"},
        {"name": "Calling Agent", "status": "idle"},
        {"name": "Diagnosis Agent", "status": "idle"},
        {"name": "Messaging Agent", "status": "idle"},
        {"name": "Summary Agent", "status": "idle"}
    ];
    for step in session.agent_path {
        parts = step.split(":");
        if parts.length > 1 {
            agent_name = parts[0];
            status = parts[1];
            for item in agent_trace {
                if item["name"] == agent_name {
                    item["status"] = status;
                }
            }
        }
    }
    transcript_list: list = [];
    for m in session.transcript {
        transcript_list.append({
            "role": m.role,
            "content": m.content,
            "timestamp": m.timestamp,
            "agent": m.agent
        });
    }
    codes_list: list = [];
    for c in session.assigned_codes {
        codes_list.append({
            "code": c.code,
            "description": c.description,
            "category": c.category,
            "confidence": c.confidence,
            "source": c.source
        });
    }
    providers_list: list = [];
    for p in session.provider_options {
        providers_list.append({
            "name": p.name,
            "specialty": p.specialty,
            "address": p.address,
            "phone": p.phone,
            "accepts_insurance": p.accepts_insurance,
            "distance_miles": p.distance_miles,
            "rating": p.rating,
            "accepting_new_patients": p.accepting_new_patients,
            "telehealth_available": p.telehealth_available,
            "notes": p.notes
        });
    }
    return {
        "session_id": session.session_id,
        "created_at": session.created_at,
        "updated_at": session.updated_at,
        "active_agent": session.active_agent,
        "transcript": transcript_list,
        "extracted_symptoms": session.extracted_symptoms,
        "risk_flags": session.risk_flags,
        "assigned_codes": codes_list,
        "provider_options": providers_list,
        "agent_path": session.agent_path,
        "agent_trace": agent_trace,
        "intervention_active": session.intervention_active,
        "intervention_resolved": session.intervention_resolved,
        "location": session.location,
        "insurance": session.insurance,
        "summary_text": session.summary_text,
        "disclaimer": disclaimer
    };
}
```

### Note on circular import
`append_message` and `update_session_timestamp` do a local `import from ..services.common { iso_now }`
inside the function body. This breaks the circular dependency between `models/` and `services/`.

### Verification
Run `jac check models/session.jac`. Must pass with no errors.
````

---

## Prompt 4 — Services: Common Utilities

````text
You are continuing to build **Care Anchor**. Prompts 1–3 are complete.

### Context
`services/common.jac` provides pure utility functions used by almost every other module.
No LLM calls. No graph operations. No imports from within the project — this module is at
the bottom of the dependency tree.

Key rules from `AGENTS.md`:
- `glob` at module level for constants.
- `with entry { }` required for any top-level executable statements.
- Functions are declared with `def`, not `can`.

### File to Create: `services/common.jac`

```jac
"""Shared utility functions and constants — no LLM, no graph ops."""

import uuid;
import from datetime { datetime, timezone }

glob APP_DISCLAIMER: str = "Care Anchor supports care coordination. It does not replace emergency care or professional diagnosis.";

def new_session_id() -> str {
    return str(uuid.uuid4());
}

def iso_now() -> str {
    return datetime.now(timezone.utc).isoformat();
}

def normalize_text(text: str) -> str {
    return text.lower().strip().replace("'", "").replace(",", "").replace(".", "");
}

def first_non_empty(a: str, b: str) -> str {
    if a and a.strip() != "" { return a.strip(); }
    return b.strip();
}

def merge_strings(existing: str, incoming: str) -> str {
    if not existing or existing.strip() == "" { return incoming.strip(); }
    if not incoming or incoming.strip() == "" { return existing.strip(); }
    return existing.strip();
}

def truncate(text: str, max_chars: int) -> str {
    if text.length <= max_chars { return text; }
    return text[:max_chars] + "...";
}

def transcript_excerpt(messages: list, max_messages: int) -> str {
    recent = messages[-max_messages:] if messages.length > max_messages else messages;
    lines: list = [];
    for m in recent {
        if isinstance(m, dict) {
            lines.append(m["role"].upper() + ": " + m["content"]);
        } else {
            lines.append(m.role.upper() + ": " + m.content);
        }
    }
    return "\n".join(lines);
}
```

Also create `services/__init__.jac`:

```jac
"""Care Anchor services package."""
```

### Verification
Run `jac check services/common.jac`. Must pass.
````

---

## Prompt 5 — Data Layer: Mock Providers & ICD Codes

````text
You are continuing to build **Care Anchor**. Prompts 1–4 are complete.

### Context
The data layer provides the demo dataset the app runs against. This is deterministic — no LLM,
no network, no graph ops. These functions simply return hard-coded lists that the matcher service
will filter at runtime.

### Files to Create

**`data/icd_codes.jac`**

Create a function that returns a representative subset of ICD-10-CM codes covering the demo
scenarios. Each entry must match the `DiagnosisCode` shape from `models/codes.jac`.

```jac
"""ICD-10-CM code subset for Care Anchor demo."""

import from ..models.codes { DiagnosisCode }

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
```

**`data/mock_providers.jac`**

Create a function returning ~12 mock providers spread across Austin TX, Denver CO, and telehealth,
covering the specialties: General Practice, Cardiology, Internal Medicine, Psychiatry, Gastroenterology.

```jac
"""Mock provider directory — used until a real API is wired in."""

import from ..models.provider { ProviderOption }

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
            notes="Walk-ins welcome Mon–Fri."
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
```

**`data/__init__.jac`**
```jac
"""Care Anchor data package."""

import from care_anchor.data.mock_providers { get_mock_provider_directory }
import from care_anchor.data.icd_codes { get_icd_code_library }
```

### Verification
Run `jac check data/mock_providers.jac` and `jac check data/icd_codes.jac`. Both must pass.
````
