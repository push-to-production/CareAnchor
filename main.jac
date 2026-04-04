"""Care Anchor entry point."""

import from dotenv { load_dotenv }
import from os { getenv }

glob _: bool = load_dotenv() or True;

cl import from .agents.orchestrator {
    create_session,
    process_message,
    get_session,
    export_json,
    export_pdf,
    load_demo
}

cl import from .components.AppShell { AppShell }

cl {
    def:pub app() -> JsxElement {
        return <AppShell />;
    }
}
