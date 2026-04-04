"""Right sidebar: symptoms, ICD codes, providers, summary text."""

import from .ProviderCard { ProviderCard }

def:pub SummaryPanel(session: dict) -> JsxElement {
    symptoms = session["extracted_symptoms"] if "extracted_symptoms" in session else [];
    codes = session["assigned_codes"] if "assigned_codes" in session else [];
    providers = session["provider_options"] if "provider_options" in session else [];
    summary_text = session["summary_text"] if "summary_text" in session else None;
    location = session["location"] if "location" in session else None;
    insurance = session["insurance"] if "insurance" in session else None;

    return <div className="summary-panel">
        {(location != None or insurance != None) and
            <div>
                <h3>Patient Info</h3>
                {location != None and <div className="summary-panel__item">📍 {location}</div>}
                {insurance != None and <div className="summary-panel__item">🏥 {insurance}</div>}
            </div>
        }

        {symptoms.length > 0 and
            <div>
                <h3>Reported Symptoms</h3>
                <div>{[<span key={String(i)} className="code-tag">{sym}</span> for (i, sym) in enumerate(symptoms)]}</div>
            </div>
        }

        {codes.length > 0 and
            <div>
                <h3>Matched Conditions</h3>
                {[<div key={c["code"]} style={{"marginBottom": "6px"}}>
                    <span className="code-tag">{c["code"]}</span>
                    <span style={{"fontSize": "0.8rem", "marginLeft": "6px"}}>{c["description"]}</span>
                </div> for c in codes]}
            </div>
        }

        {providers.length > 0 and
            <div>
                <h3>Matched Providers</h3>
                {[<ProviderCard key={p["name"]} provider={p} /> for p in providers]}
            </div>
        }

        {summary_text != None and summary_text != "" and
            <div>
                <h3>Summary</h3>
                <div className="summary-panel__item" style={{"fontSize": "0.82rem", "lineHeight": "1.5"}}>{summary_text}</div>
            </div>
        }

        {symptoms.length == 0 and codes.length == 0 and providers.length == 0 and
            <div style={{"color": "#6b7280", "fontSize": "0.82rem"}}>
                Describe your symptoms and I'll populate this panel.
            </div>
        }
    </div>;
}
