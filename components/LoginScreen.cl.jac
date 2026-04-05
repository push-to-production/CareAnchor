"""Phone number + password login / sign-up screen."""

sv import from __main__ { register_or_login }

def:pub format_phone(raw: str) -> str {
    digits = "";
    for ch in raw {
        if ch >= "0" and ch <= "9" { digits = digits + ch; }
    }
    digits = digits[:10];
    n = digits.length;
    if n == 0 { return ""; }
    if n <= 3 { return "(" + digits; }
    if n <= 6 { return "(" + digits[:3] + ") " + digits[3:]; }
    return "(" + digits[:3] + ") " + digits[3:6] + "-" + digits[6:];
}

def:pub LoginScreen(props: dict) -> JsxElement {
    has phone: str = "";
    has password: str = "";
    has loading: bool = false;
    has error: str = "";

    async def handleSubmit() -> None {
        digits = "";
        for ch in phone {
            if ch >= "0" and ch <= "9" { digits = digits + ch; }
        }
        trimmed_phone = digits;
        if trimmed_phone == "" {
            error = "Please enter your phone number.";
            return;
        }
        if password == "" {
            error = "Please enter your password.";
            return;
        }
        loading = true;
        error = "";
        try {
            result = root spawn register_or_login(phone_number=trimmed_phone, password=password);
            if result.reports.length > 0 {
                payload = result.reports[0];
                if "error" in payload {
                    error = payload["error"];
                } else {
                    props["onLogin"](payload["user"]);
                }
            } else {
                error = "Unable to sign in. Is the backend running?";
            }
        } except Exception as e {
            error = "Connection error. Please try again.";
        }
        loading = false;
    }

    def handleKeyDown(e: dict) -> None {
        if e["key"] == "Enter" { handleSubmit(); }
    }

    btn_label: str = "Signing in..." if loading else "Continue";

    return <div className="login-screen">
        <div className="login-card">
            <div className="login-brand">Care Anchor</div>
            <p className="login-tagline">AI-powered care coordination</p>
            <h2 className="login-heading">Sign in or create an account</h2>
            {error != "" and
                <div className="error-banner login-error">{error}</div>
            }
            <div className="login-field">
                <label className="login-label" htmlFor="phone">Phone number</label>
                <input
                    id="phone"
                    type="tel"
                    className="login-input"
                    placeholder="(555) 000-0000"
                    value={phone}
                    onChange={lambda e -> None { phone = format_phone(e["target"]["value"]); }}
                    onKeyDown={handleKeyDown}
                    disabled={loading}
                />
            </div>
            <div className="login-field">
                <label className="login-label" htmlFor="password">Password</label>
                <input
                    id="password"
                    type="password"
                    className="login-input"
                    placeholder="Enter your password"
                    value={password}
                    onChange={lambda e -> None { password = e["target"]["value"]; }}
                    onKeyDown={handleKeyDown}
                    disabled={loading}
                />
            </div>
            <button
                className="btn btn--primary login-btn"
                onClick={lambda -> None { handleSubmit(); }}
                disabled={loading}
            >
                {btn_label}
            </button>
            <p className="login-note">New here? Just enter your phone and a password to register.</p>
        </div>
    </div>;
}
