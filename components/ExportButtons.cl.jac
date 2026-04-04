"""Export JSON and PDF buttons."""

def:pub ExportButtons(sessionId: str, onJson: any, onPdf: any, exportStatus: str) -> JsxElement {
    disabled = sessionId == "";
    return <div className="export-buttons">
        <h3 style={{"fontSize": "0.75rem", "textTransform": "uppercase", "letterSpacing": "0.08em", "color": "#6b7280"}}>Export</h3>
        <button
            className="btn btn--secondary btn--sm"
            onClick={lambda e: any -> None { onJson(); }}
            disabled={disabled}
        >
            Export JSON
        </button>
        <button
            className="btn btn--secondary btn--sm"
            onClick={lambda e: any -> None { onPdf(); }}
            disabled={disabled}
        >
            Export PDF
        </button>
        {exportStatus != "" and
            <div className="export-status">{exportStatus}</div>
        }
    </div>;
}
