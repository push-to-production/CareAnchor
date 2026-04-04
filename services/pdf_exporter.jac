"""Writes session summary to exports/*.pdf using reportlab."""

import os;
import from models.session { UserSession }
import from .common { iso_now, APP_DISCLAIMER }

def write_session_pdf(session: UserSession) -> str {
    os.makedirs("exports", exist_ok=True);
    filename = "exports/care_anchor_" + session.session_id[:8] + ".pdf";

    try {
        import from reportlab.lib.pagesizes { letter }
        import from reportlab.platypus { SimpleDocTemplate, Paragraph, Spacer }
        import from reportlab.lib.styles { getSampleStyleSheet }

        doc = SimpleDocTemplate(filename, pagesize=letter);
        styles = getSampleStyleSheet();
        story: list = [];

        story.append(Paragraph("Care Anchor — Session Summary", styles["Title"]));
        story.append(Spacer(1, 12));
        story.append(Paragraph("Session ID: " + session.session_id, styles["Normal"]));
        story.append(Paragraph("Generated: " + iso_now(), styles["Normal"]));
        story.append(Spacer(1, 12));

        if session.extracted_symptoms {
            story.append(Paragraph("Reported Symptoms", styles["Heading2"]));
            story.append(Paragraph(", ".join(session.extracted_symptoms), styles["Normal"]));
            story.append(Spacer(1, 8));
        }

        if session.assigned_codes {
            story.append(Paragraph("Possible Related Conditions (ICD-10-CM)", styles["Heading2"]));
            for c in session.assigned_codes[:5] {
                story.append(Paragraph(c.code + " — " + c.description, styles["Normal"]));
            }
            story.append(Spacer(1, 8));
        }

        if session.provider_options {
            story.append(Paragraph("Matched Providers", styles["Heading2"]));
            for p in session.provider_options[:4] {
                story.append(Paragraph(p.name + " (" + p.specialty + ") — " + p.phone, styles["Normal"]));
            }
            story.append(Spacer(1, 8));
        }

        if session.summary_text {
            story.append(Paragraph("Summary", styles["Heading2"]));
            story.append(Paragraph(session.summary_text, styles["Normal"]));
            story.append(Spacer(1, 8));
        }

        story.append(Spacer(1, 20));
        story.append(Paragraph(APP_DISCLAIMER, styles["Italic"]));
        doc.build(story);

    } except Exception as e {
        txt_filename = filename.replace(".pdf", ".txt");
        with open(txt_filename, "w") as f {
            lines: list[str] = ["Care Anchor Session Summary", "=" * 40];
            lines.append("Session: " + session.session_id);
            if session.extracted_symptoms {
                lines.append("Symptoms: " + ", ".join(session.extracted_symptoms));
            }
            if session.summary_text {
                lines.append("Summary: " + session.summary_text);
            }
            lines.append(APP_DISCLAIMER);
            f.write("\n".join(lines));
        }
        return txt_filename;
    }

    return filename;
}
