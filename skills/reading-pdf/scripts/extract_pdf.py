#!/usr/bin/env python3
"""Fallback PDF text extraction via pypdf, used when pdftotext is unavailable.

Usage: extract_pdf.py <path-to-pdf>
"""

import sys

import pypdf


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: extract_pdf.py <path-to-pdf>", file=sys.stderr)
        return 1

    path = sys.argv[1]
    reader = pypdf.PdfReader(path)
    print(f"Pages: {len(reader.pages)}")
    for i, page in enumerate(reader.pages):
        text = page.extract_text()
        if text and text.strip():
            print(f"\n--- Page {i + 1} ---")
            print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
