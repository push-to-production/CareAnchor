"""
Real provider lookup via NLM Clinical Tables NPI API.
https://clinicaltables.nlm.nih.gov/api/npi_idv/v3/search

Response format:
  [total, [npi, ...], {extra_field: [val, ...]}, [[df_col, ...], ...]]
"""

import urllib.request
import urllib.parse
import json
import re
import ssl

NLM_BASE = "https://clinicaltables.nlm.nih.gov/api/npi_idv/v3/search"

_STATE_TO_ABBR = {
    "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR",
    "california": "CA", "colorado": "CO", "connecticut": "CT", "delaware": "DE",
    "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID",
    "illinois": "IL", "indiana": "IN", "iowa": "IA", "kansas": "KS",
    "kentucky": "KY", "louisiana": "LA", "maine": "ME", "maryland": "MD",
    "massachusetts": "MA", "michigan": "MI", "minnesota": "MN", "mississippi": "MS",
    "missouri": "MO", "montana": "MT", "nebraska": "NE", "nevada": "NV",
    "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
    "north carolina": "NC", "north dakota": "ND", "ohio": "OH", "oklahoma": "OK",
    "oregon": "OR", "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
    "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT",
    "vermont": "VT", "virginia": "VA", "washington": "WA", "west virginia": "WV",
    "wisconsin": "WI", "wyoming": "WY", "district of columbia": "DC",
}


def _normalize_state(state: str) -> str:
    """Convert full state name to 2-letter abbreviation, or return as-is if already abbreviated."""
    if not state:
        return ""
    if len(state) == 2:
        return state.upper()
    key = state.strip().lower()
    return _STATE_TO_ABBR.get(key, "").upper()

# Map internal specialty names → NLM provider_type search terms
_SPECIALTY_TERMS = {
    "Psychiatry":           "Psychiatry",
    "Neurology":            "Neurology",
    "Cardiology":           "Cardiology",
    "Gastroenterology":     "Gastroenterology",
    "Pulmonology":          "Pulmonary",
    "Orthopedics":          "Orthopedic",
    "Endocrinology":        "Endocrinology",
    "Urology":              "Urology",
    "Ophthalmology / ENT":  "Ophthalmology",
    "Dermatology":          "Dermatology",
    "Oncology":             "Oncology",
    "Infectious Disease":   "Infectious Disease",
    "Internal Medicine":    "Internal Medicine",
    "General Practice":     "General Practice",
}


def _extract_state(location: str) -> str:
    m = re.search(r',\s*([A-Za-z ]+?)\s*$', location)
    if not m:
        return ""
    raw = m.group(1).strip()
    if not raw:
        return ""
    return _normalize_state(raw)


def _extract_city(location: str) -> str:
    m = re.match(r'^([^,]+)', location.strip())
    return m.group(1).strip().upper() if m else ""


def _parse_locations(location: str) -> list:
    """
    Split a location string that may describe multiple places.

    Examples:
      "Austin, TX"                    → [("AUSTIN", "TX")]
      "Austin, TX or Denver, CO"      → [("AUSTIN", "TX"), ("DENVER", "CO")]
      "Austin, TX and Denver, CO"     → [("AUSTIN", "TX"), ("DENVER", "CO")]
      "Austin, TX / Denver, CO"       → [("AUSTIN", "TX"), ("DENVER", "CO")]

    Returns a list of (city, state) tuples (both uppercased strings, may be "").
    """
    # Normalise separators then split
    normalised = re.sub(r'\s+(?:or|and)\s+|/|;', '|', location, flags=re.IGNORECASE)
    parts = [p.strip() for p in normalised.split('|') if p.strip()]
    result = []
    for part in parts:
        city = _extract_city(part)
        state = _extract_state(part)
        if city or state:
            result.append((city, state))
    return result if result else [(_extract_city(location), _extract_state(location))]


def _ssl_ctx():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


def _fmt_phone(raw) -> str:
    if not raw:
        return ""
    digits = re.sub(r"[^\d]", "", str(raw))
    if len(digits) == 10:
        return f"({digits[:3]}) {digits[3:6]}-{digits[6:]}"
    return str(raw)


def _query(terms: str, state: str, city: str, max_list: int) -> list:
    """Run one API query; return list of raw result dicts."""
    q_parts = []
    if state:
        q_parts.append(f"addr_practice.state:{state}")
    if city:
        q_parts.append(f"addr_practice.city:{city}")

    params = {
        "terms":   terms,
        "sf":      "provider_type,addr_practice.city,addr_practice.state",
        "df":      "NPI,name.full,provider_type,addr_practice.full",
        "ef":      "name.credential,addr_practice.phone,addr_practice.city,addr_practice.zip,gender",
        "maxList": str(max_list),
    }
    if q_parts:
        params["q"] = " AND ".join(q_parts)

    url = NLM_BASE + "?" + urllib.parse.urlencode(params)
    try:
        with urllib.request.urlopen(url, context=_ssl_ctx(), timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception:
        return []

    if not data or len(data) < 4 or not data[3]:
        return []

    extra      = data[2] or {}
    rows       = data[3]
    phones     = extra.get("addr_practice.phone", [])
    creds      = extra.get("name.credential", [])
    cities     = extra.get("addr_practice.city", [])
    zips_list  = extra.get("addr_practice.zip", [])
    genders    = extra.get("gender", [])

    results = []
    for i, row in enumerate(rows):
        if len(row) < 4:
            continue
        npi          = row[0] or ""
        full_name    = (row[1] or "").strip().title()
        prov_type    = row[2] or terms
        full_address = (row[3] or "").strip()

        phone      = _fmt_phone(phones[i] if i < len(phones) else "")
        credential = (creds[i] or "").strip() if i < len(creds) else ""
        city_val   = (cities[i] or "").strip().title() if i < len(cities) else ""
        zip_val    = (zips_list[i] or "").strip() if i < len(zips_list) else ""
        gender     = (genders[i] or "").strip() if i < len(genders) else ""

        display_name = full_name
        if credential and credential not in display_name:
            display_name = f"{full_name}, {credential}"

        results.append({
            "npi":                    npi,
            "name":                   display_name,
            "specialty":              prov_type,
            "address":                full_address,
            "phone":                  phone,
            "accepts_insurance":      [],   # NPI registry has no insurance data
            "distance_miles":         0.0,
            "rating":                 0.0,
            "accepting_new_patients": True,
            "telehealth_available":   False,
            "notes":                  f"Verify insurance. NPI {npi}.",
            "_city":                  city_val,
            "_zip":                   zip_val,
            "_gender":                gender,
        })
    return results


def search_providers_npi(
    specialties: list,
    location: str,
    max_results: int = 6,
) -> list:
    """
    Fetch real NPI providers for the given specialties and location.

    Strategy:
      1. For each specialty, try city+state query first.
      2. If city query returns < 3 results, retry with state-only.
      3. Deduplicate by NPI across specialties.
      4. Return up to max_results records.

    Returns list of dicts with keys matching ProviderOption fields.
    """
    # Support multiple locations (e.g. "Austin, TX or Denver, CO")
    locations = _parse_locations(location)
    num_locs  = len(locations)

    seen_npi = set()
    results  = []

    for spec in specialties[:3]:
        if len(results) >= max_results:
            break

        terms = _SPECIALTY_TERMS.get(spec, spec)
        fetch = max_results * 4   # fetch more than needed to allow dedup

        # Gather a bucket of candidates per location, then interleave so
        # every provided location gets fair representation in the final list.
        per_loc_batches = []
        for city, state in locations:
            # --- city + state ---
            batch = _query(terms, state, city, fetch)

            # --- fall back to state-only if city query is thin ---
            if len(batch) < 3 and state:
                batch = _query(terms, state, "", fetch)

            # --- nationwide fallback ONLY when no location was provided at all ---
            # If a city or state was specified, we must NOT return out-of-area
            # providers just because the NPI registry has sparse coverage there.
            if not batch and not city and not state:
                batch = _query(terms, "", "", fetch)

            per_loc_batches.append(batch)

        # Round-robin interleave across location buckets so the final list
        # alternates between locations (Austin, Denver, Austin, Denver …).
        max_bucket = max((len(b) for b in per_loc_batches), default=0)
        for i in range(max_bucket):
            for bucket in per_loc_batches:
                if i >= len(bucket):
                    continue
                rec = bucket[i]
                npi = rec["npi"]
                if npi and npi in seen_npi:
                    continue
                if npi:
                    seen_npi.add(npi)
                results.append(rec)
                if len(results) >= max_results:
                    break
            if len(results) >= max_results:
                break

    # Strip internal "_" helper keys before returning
    clean = []
    for r in results:
        clean.append({k: v for k, v in r.items() if not k.startswith("_")})
    return clean


# ---------------------------------------------------------------------------
# Manual test
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    test_cases = [
        (["Psychiatry"],        "Chicago, IL"),
        (["Neurology"],         "Seattle, WA"),
        (["Cardiology"],        "Denver, CO"),
        (["General Practice"],  "Austin, TX"),
        (["Gastroenterology"],  "Miami, FL"),
        (["Internal Medicine"], "New York, NY"),
        (["Psychiatry", "Neurology"], "Boston, MA"),
    ]
    for specs, loc in test_cases:
        print(f"\n=== {specs} in {loc} ===")
        providers = search_providers_npi(specs, loc, max_results=3)
        if not providers:
            print("  NO RESULTS")
        for p in providers:
            print(f"  {p['name']} | {p['specialty']} | {p['address']} | {p['phone']}")
