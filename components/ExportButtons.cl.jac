"""Export JSON and PDF buttons."""

def:pub ExportButtons(sessionId: str, onJson: any, onPdf: any, exportStatus: str) -> JsxElement {
    disabled = sessionId == "";
    return <div className="export-buttons panel">
        <div className="panel__eyebrow">Export</div>
        <div className="export-buttons__row">
            <button
                type="button"
                className="btn btn--secondary btn--sm"
                onClick={onJson}
                disabled={disabled}
            >
                Export JSON
            </button>
            <button
                type="button"
                className="btn btn--secondary btn--sm"
                onClick={onPdf}
                disabled={disabled}
            >
                Export PDF
            </button>
        </div>
        {exportStatus != "" and
            <div className="export-status">{exportStatus}</div>
        }
    </div>;
}
