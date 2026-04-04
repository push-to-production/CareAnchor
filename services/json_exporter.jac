"""Writes session summary to exports/*.json."""

import json;
import os;
import from models.session { UserSession, session_to_dict }
import from .common { iso_now }

def write_session_json(session: UserSession) -> str {
    os.makedirs("exports", exist_ok=True);
    filename = "exports/care_anchor_" + session.session_id[:8] + ".json";
    data = session_to_dict(session);
    data["exported_at"] = iso_now();
    with open(filename, "w") as f {
        f.write(json.dumps(data, indent=2));
    }
    return filename;
}
