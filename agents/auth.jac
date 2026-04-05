"""Authentication walkers — register or login by phone number and password."""

import from models.user { User, user_to_dict, hash_password }
import from services.common { new_session_id, iso_now }

def find_user_by_phone(phone: str) -> User | None {
    anchor = root();
    users = [u for u in [anchor -->](?:User) if u.phone_number == phone];
    if users { return users[0]; }
    return None;
}

walker :pub register_or_login {
    has phone_number: str;
    has password: str;

    can start with Root entry {
        phone = self.phone_number.strip();
        if phone == "" {
            report {"error": "Phone number is required"};
            disengage;
        }
        if self.password == "" {
            report {"error": "Password is required"};
            disengage;
        }
        pw_hash = hash_password(self.password);
        existing = find_user_by_phone(phone);
        if existing == None {
            uid = new_session_id();
            now = iso_now();
            created = root ++> User(phone_number=phone, user_id=uid, created_at=now, password_hash=pw_hash);
            existing = created[0];
            commit();
            report {"user": user_to_dict(existing), "is_new": True};
        } else {
            if existing.password_hash != pw_hash {
                report {"error": "Incorrect password"};
                disengage;
            }
            report {"user": user_to_dict(existing), "is_new": False};
        }
    }
}
