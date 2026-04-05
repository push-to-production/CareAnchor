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
        <div className="chat-window__header">
            <div>
                <div className="panel__eyebrow">Live conversation</div>
                <h2>Care conversation</h2>
            </div>
            <div className="chat-window__status">
                <span className="status-dot"></span>
                <span>{activeAgent}</span>
            </div>
        </div>

        <div className="chat-feed">
            {transcript.length == 0 and
                <div className="chat-empty-state">
                    <h3>Start with symptoms, location, and insurance.</h3>
                    <p>
                        Care Anchor will route the conversation through the agent pipeline,
                        identify risk signals, suggest likely codes, and match providers.
                    </p>
                </div>
            }

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
            <div className="chat-composer__input">
                <textarea
                    placeholder="Type your message..."
                    value={draft}
                    onChange={lambda e: any -> None { onDraftChange(e.target.value); }}
                    onKeyDown={lambda e: any -> None { handle_key_down(e); }}
                    disabled={sending}
                    rows={2}
                />
            </div>
            <button
                type="button"
                className="btn btn--primary"
                onClick={onSend}
                disabled={sending or draft.trim() == ""}
            >
                Send
            </button>
        </div>

        <div className="demo-bar">
            <span className="demo-bar__label">Demo cases</span>
            <button type="button" className="btn btn--secondary btn--sm" onClick={lambda -> None { onDemo(1); }} disabled={sending}>
                Dizziness
            </button>
            <button type="button" className="btn btn--secondary btn--sm" onClick={lambda -> None { onDemo(2); }} disabled={sending}>
                Nausea
            </button>
            <button type="button" className="btn btn--crisis btn--sm" onClick={lambda -> None { onDemo(3); }} disabled={sending}>
                Crisis
            </button>
            <button type="button" className="btn btn--secondary btn--sm" style={{"marginLeft": "auto"}} onClick={onReset} disabled={sending}>
                New Session
            </button>
        </div>
    </div>;
}
