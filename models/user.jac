"""User graph node for phone-based authentication."""

import hashlib;

node User {
    has phone_number: str;
    has user_id: str;
    has created_at: str;
    has password_hash: str = "";
}

def hash_password(password: str) -> str {
    return hashlib.sha256(password.encode()).hexdigest();
}

def user_to_dict(user: User) -> dict {
    return {
        "user_id": user.user_id,
        "phone_number": user.phone_number,
        "created_at": user.created_at
    };
}
