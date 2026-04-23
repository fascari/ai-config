---
name: reading-pdf
description: Use when a PDF file path is provided or attached and its text content must be read, extracted, summarized, or answered about
---

# Reading PDF

## Overview

Extracts text from PDF files using `pdftotext` (Poppler) as the primary tool, with `pypdf` as a fallback when Poppler is not available. Text only — no OCR, no images, no form fields.

`pdftotext` is preferred because it is faster, handles column layouts and kerning correctly, preserves word boundaries at inline style transitions, and normalizes common ligatures (`ﬁ`/`ﬂ`) that `pypdf` leaves as Unicode characters.

## When to use

- User attaches or references a PDF file (`@path/to/file.pdf`)
- User asks to read, summarize, or analyze a PDF
- Another skill needs text content from a PDF file
- User asks questions about content inside a PDF

**When NOT to use:** scanned image PDFs (no embedded text). Report that OCR is required and stop.

## Steps

1. **Resolve path**: identify the PDF file path from the conversation context or user message. Resolve relative paths against the current working directory.

2. **Verify the file exists**: confirm the file is present before proceeding. If not found, report the exact path and stop.

3. **Detect available tool**:

```bash
if command -v pdftotext >/dev/null 2>&1; then
  TOOL=pdftotext
else
  TOOL=pypdf
fi
```

If neither is available, attempt to install `pdftotext` first (`brew install poppler` on macOS, `apt-get install poppler-utils` on Debian/Ubuntu). Fall back to the `pypdf` path only when installing Poppler is not possible.

4. **Extract text — primary path (`pdftotext`)**:

Default mode preserves visual layout (`-layout`), which is best for tables and multi-column documents:

```bash
pdftotext -layout <PATH_TO_PDF> -
```

For parser-order extraction (useful when simulating how a simple ATS or byte-stream reader consumes the file), use `-raw`:

```bash
pdftotext -raw <PATH_TO_PDF> -
```

For a specific page range, use `-f <first>` and `-l <last>`:

```bash
pdftotext -layout -f 1 -l 3 <PATH_TO_PDF> -
```

`pdftotext` emits a form-feed character (`\f`) between pages. To produce readable page markers:

```bash
pdftotext -layout <PATH_TO_PDF> - | awk 'BEGIN{p=1;print "--- Page "p" ---"} /\f/{p++;print "\n--- Page "p" ---";next} {print}'
```

5. **Extract text — fallback path (`pypdf`)**:

Only when `pdftotext` is unavailable. Set up the environment once:

```bash
python3 -m venv /tmp/copilot-pdf-env 2>/dev/null || true
/tmp/copilot-pdf-env/bin/pip install pypdf -q 2>/dev/null
```

Write the extraction script to a temp file (never use heredocs):

```python
# /tmp/extract_pdf.py
import pypdf

path = "PATH_TO_PDF"
reader = pypdf.PdfReader(path)
print(f"Pages: {len(reader.pages)}")
for i, page in enumerate(reader.pages):
    text = page.extract_text()
    if text and text.strip():
        print(f"\n--- Page {i + 1} ---")
        print(text)
```

Use the `create` tool to write this script to `/tmp/extract_pdf.py`, replacing `PATH_TO_PDF` with the resolved absolute path, then run:

```bash
/tmp/copilot-pdf-env/bin/python3 /tmp/extract_pdf.py
```

6. **Present the content**: return the text structured by page markers (`--- Page N ---`). If the file has more than 10 pages, summarize each page instead of dumping full text unless the user asks for raw content.

7. **Handle encrypted PDFs**:
   - `pdftotext`: pass the password via `-upw <PASSWORD>` (user password) or `-opw <PASSWORD>` (owner password).
   - `pypdf`: add `reader.decrypt("PASSWORD")` before iterating pages. If `FileNotDecryptedError` is raised, ask the user for the password.

## Output

- Tool used (`pdftotext` or `pypdf`) and resolved file path
- Page count
- Full extracted text separated by `--- Page N ---` markers
- If all pages yield empty text: warn that the PDF is likely image-based and OCR is needed

## When to pick `-layout` vs `-raw` (pdftotext only)

| Intent | Flag |
|---|---|
| Read content for a human (summarize, answer questions) | `-layout` (default) |
| Simulate how an ATS or simple byte-stream parser reads the file | `-raw` |
| Compare both to detect column-interleave or layout bugs | Run both, diff the outputs |

## Constraints

- Read-only: never modifies the PDF
- No OCR on image-based PDFs
- No image, table, or form field extraction; text only
- No file content sent to external services

## Common mistakes

| Mistake | Fix |
|---|---|
| Defaulting to `pypdf` when `pdftotext` is installed | Detect `pdftotext` first and use it as the primary tool |
| Using `-layout` to simulate ATS parsing | Use `-raw` when the intent is parser-order extraction |
| Using heredoc (`<<EOF`) to pass the Python fallback script | Write to `/tmp/extract_pdf.py` with the `create` tool, then execute |
| Passing a relative path to either tool | Resolve to absolute path before invoking |
| Dumping all pages raw for a 50-page document | Summarize per page when the file has more than 10 pages |
| Ignoring empty-text pages silently | Always report if some pages produced no text |

## Error recovery

| Error | Action |
|---|---|
| Neither `pdftotext` nor `pypdf` available | Attempt `brew install poppler` (macOS) or `apt-get install poppler-utils` (Linux); if that fails, fall back to installing `pypdf` in the venv |
| File not found | Report exact path; ask user to confirm location |
| `pdftotext` exits with "Incorrect password" | Ask for the password, then retry with `-upw` |
| `FileNotDecryptedError` (pypdf fallback) | Ask for the password, then retry with `reader.decrypt()` |
| Empty text on all pages | Warn that the PDF is likely image-based; OCR is not supported |
| `pypdf` install fails | Ask the user to run `pip3 install pypdf` manually |

