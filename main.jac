"""Care Anchor entry point."""

import from dotenv { load_dotenv }
import from os { getenv }

glob _: bool = load_dotenv() or True;

sv import from agents.auth { register_or_login, get_user_by_token, logout }
sv import from agents.orchestrator {
    create_session,
    process_message,
    get_session,
    export_json,
    export_pdf,
    load_demo,
    list_sessions,
    load_session
}

cl import from .components.AppShell { AppShell }

cl {
    def:pub app() -> JsxElement {
        return <AppShell />;
    }
}
