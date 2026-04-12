---
name: reading-pdf
description: Use when a PDF file path is provided or attached and its text content must be read, extracted, summarized, or answered about
---

# Reading PDF

## Overview

Extracts text from PDF files page by page using `pypdf` in an isolated virtualenv. Text only — no OCR, no images, no form fields.

## When to use

- User attaches or references a PDF file (`@path/to/file.pdf`)
- User asks to read, summarize, or analyze a PDF
- Another skill needs text content from a PDF file
- User asks questions about content inside a PDF

**When NOT to use:** scanned image PDFs (no embedded text). Report that OCR is required and stop.

## Steps

1. **Resolve path**: identify the PDF file path from the conversation context or user message. Resolve relative paths against the current working directory.

2. **Verify the file exists**: confirm the file is present before proceeding. If not found, report the exact path and stop.

3. **Ensure pypdf is available**:

```bash
python3 -m venv /tmp/copilot-pdf-env 2>/dev/null || true
/tmp/copilot-pdf-env/bin/pip install pypdf -q 2>/dev/null
```

4. **Write extraction script** to a temp file (never use heredocs):

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

Use the `create` tool to write this script to `/tmp/extract_pdf.py`, replacing `PATH_TO_PDF` with the resolved absolute path.

5. **Run the script**:

```bash
/tmp/copilot-pdf-env/bin/python3 /tmp/extract_pdf.py
```

6. **Present the content**: return the text structured by page. If the file has more than 10 pages, summarize each page instead of dumping full text unless the user asks for raw content.

7. **Handle encrypted PDFs**: if `FileNotDecryptedError` is raised, report that the file is password-protected and ask for the password. Then add `reader.decrypt("PASSWORD")` before iterating pages.

## Output

- Page count and resolved file path
- Full extracted text separated by `--- Page N ---` markers
- If all pages yield empty text: warn that the PDF is likely image-based and OCR is needed

## Constraints

- Read-only: never modifies the PDF
- No OCR on image-based PDFs
- No image, table, or form field extraction; text only
- No file content sent to external services

## Common mistakes

| Mistake | Fix |
|---|---|
| Using heredoc (`<<EOF`) to pass the Python script | Write the script to `/tmp/extract_pdf.py` with the `create` tool, then execute it |
| Passing a relative path to `pypdf.PdfReader` | Resolve to absolute path before writing the script |
| Printing all pages raw for a 50-page document | Summarize per page when the file has more than 10 pages |
| Ignoring empty-text pages silently | Always report if some pages produced no text |

## Error recovery

| Error | Action |
|---|---|
| File not found | Report exact path; ask user to confirm location |
| `FileNotDecryptedError` | Ask for the password, then retry with `reader.decrypt()` |
| Empty text on all pages | Warn that the PDF is likely image-based; OCR is not supported |
| `pypdf` install fails | Ask the user to run `pip3 install pypdf` manually |
