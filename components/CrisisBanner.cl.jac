"""Crisis safety banner — shown when intervention_active is True."""

def:pub CrisisBanner(active: bool, riskFlags: list) -> JsxElement {
    if not active {
        return <div></div>;
    }
    return <div className="crisis-banner">
        <strong>Safety alert.</strong> If you are in immediate danger, call <strong>911</strong> or text <strong>988</strong> for the Suicide and Crisis Lifeline.
        {riskFlags.length > 0 and
            <div className="crisis-banner__flags">
                {[<span key={String(i)}>{flag} </span> for (i, flag) in enumerate(riskFlags)]}
            </div>
        }
    </div>;
}
