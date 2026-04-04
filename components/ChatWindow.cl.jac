"""Chat message feed and composer."""

cl import from react { useEffect, useRef }
import from .MessageBubble { MessageBubble }

def:pub ChatWindow(
    transcript: list,
    draft: str,
    sending: bool,
    activeAgent: str,
    onDraftChange: any,
    onSend: any,
    onDemo: any,
    onReset: any
) -> JsxElement {
    endRef = useRef(None);

    useEffect(lambda -> None {
        if endRef.current { endRef.current.scrollIntoView({"behavior": "smooth"}); }
    }, [transcript]);

    def handle_key_down(e: any) -> None {
        if e.key == "Enter" and not e.shiftKey {
            e.preventDefault();
            onSend();
        }
    }

    return <div className="chat-window">
        <div className="chat-feed">
            {[<MessageBubble key={String(i)} msg={msg} /> for (i, msg) in enumerate(transcript)]}
            {sending and
                <div className="bubble bubble--assistant">
                    <div className="bubble__body" style={{"opacity": "0.6", "fontStyle": "italic"}}>
                        {activeAgent + " is thinking..."}
                    </div>
                </div>
            }
            <div ref={endRef}></div>
        </div>

        <div className="chat-composer">
            <textarea
                placeholder="Describe your symptoms, location, and insurance..."
                value={draft}
                onChange={lambda e: any -> None { onDraftChange(e.target.value); }}
                onKeyDown={lambda e: any -> None { handle_key_down(e); }}
                disabled={sending}
                rows={2}
            />
            <button
                className="btn btn--primary"
                onClick={lambda e: any -> None { onSend(); }}
                disabled={sending or draft.trim() == ""}
            >
                Send
            </button>
        </div>

        <div className="demo-bar">
            <span>Demo cases:</span>
            <button className="btn btn--secondary btn--sm" onClick={lambda e: any -> None { onDemo(1); }} disabled={sending}>
                Case 1 (Dizziness)
            </button>
            <button className="btn btn--secondary btn--sm" onClick={lambda e: any -> None { onDemo(2); }} disabled={sending}>
                Case 2 (Nausea)
            </button>
            <button className="btn btn--crisis btn--sm" onClick={lambda e: any -> None { onDemo(3); }} disabled={sending}>
                Case 3 (Crisis)
            </button>
            <button className="btn btn--secondary btn--sm" style={{"marginLeft": "auto"}} onClick={lambda e: any -> None { onReset(); }} disabled={sending}>
                New Session
            </button>
        </div>
    </div>;
}
