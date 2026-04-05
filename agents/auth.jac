"""Authentication walkers — register or login by phone number and password."""

import secrets;
import from models.user { User, user_to_dict, hash_password }
import from services.common { new_session_id, iso_now }

def find_user_by_phone(phone: str) -> User | None {
    anchor = root();
    users = [u for u in [anchor -->](?:User) if u.phone_number == phone];
    if users { return users[0]; }
    return None;
}

def find_user_by_token(token: str) -> User | None {
    anchor = root();
    users = [u for u in [anchor -->](?:User) if u.session_token == token];
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
        token = secrets.token_hex(32);
        existing = find_user_by_phone(phone);
        if existing == None {
            uid = new_session_id();
            now = iso_now();
            created = root ++> User(
                phone_number=phone,
                user_id=uid,
                created_at=now,
                password_hash=pw_hash,
                session_token=token
            );
            existing = created[0];
            commit();
            report {"user": user_to_dict(existing), "token": token, "is_new": True};
        } else {
            if existing.password_hash != pw_hash {
                report {"error": "Incorrect password"};
                disengage;
            }
            existing.session_token = token;
            commit();
            report {"user": user_to_dict(existing), "token": token, "is_new": False};
        }
    }
}

walker :pub get_user_by_token {
    has token: str;

    can start with Root entry {
        if self.token == "" {
            report {"error": "Token is required"};
            disengage;
        }
        user = find_user_by_token(self.token);
        if user == None {
            report {"error": "Invalid or expired session"};
            disengage;
        }
        report {"user": user_to_dict(user)};
    }
}

walker :pub logout {
    has token: str;

    can start with Root entry {
        user = find_user_by_token(self.token);
        if user != None {
            user.session_token = "";
            commit();
        }
        report {"ok": True};
    }
}
