"""Single provider result card."""

def:pub ProviderCard(provider: dict) -> JsxElement {
    name = provider["name"] if "name" in provider else "Unknown Provider";
    specialty = provider["specialty"] if "specialty" in provider else "";
    address = provider["address"] if "address" in provider else "";
    phone = provider["phone"] if "phone" in provider else "";
    telehealth = provider["telehealth_available"] if "telehealth_available" in provider else False;
    rating = provider["rating"] if "rating" in provider else 0.0;
    notes = provider["notes"] if "notes" in provider else "";

    return <div className="provider-card">
        <div className="provider-card__name">{name}</div>
        <div className="provider-card__detail">{specialty}</div>
        {address != "" and <div className="provider-card__detail">{address}</div>}
        {phone != "" and <div className="provider-card__detail">{phone}</div>}
        <div style={{"display": "flex", "gap": "4px", "flexWrap": "wrap", "marginTop": "4px"}}>
            {telehealth and <span className="provider-card__badge">Telehealth</span>}
            {rating > 0.0 and <span className="provider-card__badge">{"★ " + String(rating)}</span>}
        </div>
        {notes != "" and <div className="provider-card__detail" style={{"marginTop": "4px", "fontStyle": "italic"}}>{notes}</div>}
    </div>;
}
