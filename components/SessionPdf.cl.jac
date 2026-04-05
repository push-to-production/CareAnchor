"""Client-side PDF document for session exports."""

cl import from "@react-pdf/renderer" { Document, Page, Text, View, pdf }
cl import from "react-pdf-html" { default as Html }

def pdf_styles() -> dict {
    return {
        "page": {
            "paddingTop": 34,
            "paddingBottom": 46,
            "paddingHorizontal": 34,
            "backgroundColor": "#ffffff",
            "color": "#163247"
        },
        "header": {
            "marginBottom": 18,
            "paddingBottom": 12,
            "borderBottomWidth": 1,
            "borderBottomColor": "#d7e6f2"
        },
        "kicker": {
            "fontSize": 10,
            "fontWeight": 800,
            "letterSpacing": 1.4,
            "color": "#174f96",
            "marginBottom": 6
        },
        "title": {
            "fontSize": 20,
            "fontWeight": 800,
            "marginBottom": 6
        },
        "meta": {
            "fontSize": 10,
            "color": "#5e7184",
            "marginBottom": 2
        },
        "html": {
            "fontSize": 10,
            "lineHeight": 1.5,
            "color": "#163247"
        },
        "footer": {
            "position": "absolute",
            "left": 34,
            "right": 34,
            "bottom": 18,
            "paddingTop": 8,
            "borderTopWidth": 1,
            "borderTopColor": "#d7e6f2"
        },
        "footerText": {
            "fontSize": 9,
            "color": "#70869a"
        }
    };
}

def:pub SessionPdfDocument(payload: dict) -> JsxElement {
    styles = pdf_styles();
    session_id = payload["session_id"] if "session_id" in payload else "";
    generated_at = payload["generated_at"] if "generated_at" in payload else "";
    html_content = payload["html_content"] if "html_content" in payload else "<p>No session export content is available.</p>";
    disclaimer = payload["disclaimer"] if "disclaimer" in payload else "";

    return <Document title={"AnchorCare Session " + session_id}>
        <Page size="A4" style={styles["page"]} wrap>
            <View style={styles["header"]}>
                <Text style={styles["kicker"]}>ANCHORCARE</Text>
                <Text style={styles["title"]}>AnchorCare Dashboard Session Export</Text>
                <Text style={styles["meta"]}>Session ID: {session_id}</Text>
                <Text style={styles["meta"]}>Exported: {generated_at}</Text>
            </View>

            <Html style={styles["html"]}>{html_content}</Html>

            <View fixed style={styles["footer"]}>
                <Text style={styles["footerText"]}>{disclaimer}</Text>
            </View>
        </Page>
    </Document>;
}

async def:pub build_session_pdf_attachment(payload: dict) -> dict | None {
    doc = <SessionPdfDocument payload={payload} />;
    instance = pdf(doc);
    blob = await instance.toBlob();
    url = URL.createObjectURL(blob);
    file_name = payload["file_name"] if "file_name" in payload else "anchorcare_session.pdf";
    mime_type = payload["mime_type"] if "mime_type" in payload else "application/pdf";

    return {
        "label": file_name,
        "href": url,
        "download_name": file_name,
        "mime_type": mime_type
    };
}
