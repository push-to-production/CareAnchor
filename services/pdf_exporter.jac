"""Builds session summary PDF payloads in memory without external dependencies."""

import base64;
import textwrap;
import from models.session { UserSession }
import from .common { iso_now, APP_DISCLAIMER }

def _escape_pdf_text(text: str) -> str {
    return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)");
}

def _offset_label(value: int) -> str {
    raw = str(value);
    while len(raw) < 10 {
        raw = "0" + raw;
    }
    return raw;
}

def _wrapped_lines(text: str, width: int = 82) -> list[str] {
    wrapped = textwrap.wrap(text, width=width) if text and text.strip() != "" else [];
    return wrapped if wrapped else [""];
}

def _session_lines(session: UserSession, generated_at: str) -> list[str] {
    lines: list[str] = [
        "Care Anchor Session Summary",
        "",
        "Session ID: " + session.session_id,
        "Generated: " + generated_at,
        ""
    ];

    if session.extracted_symptoms {
        lines.append("Reported Symptoms");
        for symptom in session.extracted_symptoms {
            lines.extend(_wrapped_lines("- " + symptom));
        }
        lines.append("");
    }

    if session.assigned_codes {
        lines.append("Possible Related Conditions (ICD-10-CM)");
        for c in session.assigned_codes[:5] {
            code = c["code"] if isinstance(c, dict) else c.code;
            description = c["description"] if isinstance(c, dict) else c.description;
            lines.extend(_wrapped_lines("- " + str(code) + ": " + str(description)));
        }
        lines.append("");
    }

    if session.provider_options {
        lines.append("Matched Providers");
        for p in session.provider_options[:4] {
            name = p["name"] if isinstance(p, dict) else p.name;
            specialty = p["specialty"] if isinstance(p, dict) else p.specialty;
            phone = p["phone"] if isinstance(p, dict) else p.phone;
            lines.extend(_wrapped_lines("- " + str(name) + " (" + str(specialty) + ") - " + str(phone)));
        }
        lines.append("");
    }

    if session.summary_text and session.summary_text.strip() != "" {
        lines.append("Summary");
        lines.extend(_wrapped_lines(session.summary_text));
        lines.append("");
    }

    lines.extend(_wrapped_lines(APP_DISCLAIMER));
    return lines;
}

def _content_stream(page_lines: list[str]) -> str {
    commands: list[str] = [
        "BT",
        "/F1 12 Tf",
        "72 742 Td",
        "14 TL"
    ];

    first_line = True;
    for line in page_lines {
        escaped = _escape_pdf_text(line);
        if first_line {
            commands.append("(" + escaped + ") Tj");
            first_line = False;
        } else {
            commands.append("T*");
            commands.append("(" + escaped + ") Tj");
        }
    }
    commands.append("ET");
    return "\n".join(commands);
}

def _build_pdf_bytes(lines: list[str]) -> bytes {
    lines_per_page = 45;
    page_streams: list[str] = [];
    start = 0;

    while start < len(lines) {
        stop = start + lines_per_page;
        page_streams.append(_content_stream(lines[start:stop]));
        start = stop;
    }

    if len(page_streams) == 0 {
        page_streams = [_content_stream(["Care Anchor Session Summary"])];
    }

    object_count = 3 + (len(page_streams) * 2);
    font_object_id = object_count;
    objects: list[str] = [];

    objects.append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");

    kids: list[str] = [];
    for page_index in range(len(page_streams)) {
        page_object_id = 3 + (page_index * 2);
        kids.append(str(page_object_id) + " 0 R");
    }
    objects.append(
        "2 0 obj\n<< /Type /Pages /Kids [" + " ".join(kids) + "] /Count " + str(len(page_streams)) + " >>\nendobj\n"
    );

    for page_index in range(len(page_streams)) {
        stream = page_streams[page_index];
        page_object_id = 3 + (page_index * 2);
        content_object_id = page_object_id + 1;
        objects.append(
            str(page_object_id) + " 0 obj\n"
            + "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
            + "/Resources << /Font << /F1 " + str(font_object_id) + " 0 R >> >> "
            + "/Contents " + str(content_object_id) + " 0 R >>\n"
            + "endobj\n"
        );
        objects.append(
            str(content_object_id) + " 0 obj\n"
            + "<< /Length " + str(len(stream)) + " >>\n"
            + "stream\n"
            + stream + "\n"
            + "endstream\n"
            + "endobj\n"
        );
    }

    objects.append(
        str(font_object_id) + " 0 obj\n"
        + "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\n"
        + "endobj\n"
    );

    pdf = "%PDF-1.4\n";
    offsets: list[int] = [0];
    for obj in objects {
        offsets.append(len(pdf));
        pdf += obj;
    }

    xref_start = len(pdf);
    pdf += "xref\n0 " + str(len(objects) + 1) + "\n";
    pdf += "0000000000 65535 f \n";
    for offset in offsets[1:] {
        pdf += _offset_label(offset) + " 00000 n \n";
    }
    pdf += "trailer\n<< /Size " + str(len(objects) + 1) + " /Root 1 0 R >>\n";
    pdf += "startxref\n" + str(xref_start) + "\n%%EOF";
    return pdf.encode("latin-1", errors="replace");
}

def build_session_pdf_payload(session: UserSession) -> dict {
    filename = "care_anchor_" + session.session_id[:8] + ".pdf";
    generated_at = iso_now();
    pdf_bytes = _build_pdf_bytes(_session_lines(session, generated_at));
    return {
        "file_name": filename,
        "mime_type": "application/pdf",
        "content_base64": base64.b64encode(pdf_bytes).decode("utf-8"),
        "generated_at": generated_at,
        "session_id": session.session_id
    };
}
