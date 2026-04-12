---
name: writing-cv
description: Use when generating a tailored HTML resume and PDF for a specific job description
---

# Writing CV

## Overview

Generates a tailored HTML resume for a specific role by mapping the base resume at `docs/resume/felipe-ascari-resume.html` to the job description. Produces a self-contained HTML file and a PDF via `mise run validate-pdf`. Content changes; CSS and visual structure never change.

## When to use

- User provides a job posting URL or job description text and asks to create a tailored resume
- User asks to apply for a specific role and needs a targeted CV
- User provides a list of application form questions alongside a job description

## When NOT to use

- User asks for a general resume update not tied to a specific role: edit the base resume directly instead
- User wants a cover letter: use the cover letter workflow instead
- User has not provided a job description or URL

## Steps

1. **Fetch the job description**: use `web_fetch` to read the URL provided by the user. If the user provides raw text instead of a URL, skip this step and use the text directly.

2. **Extract signal from the JD**: identify the following from the job description:
   - Required technical skills and tools
   - Preferred or nice-to-have skills
   - Key responsibilities and scope of the role
   - Team context (size, stage, domain)
   - Any explicit values or working style signals

3. **Read the base resume**: read `docs/resume/felipe-ascari-resume.html` in full. Do not summarize it; you need every bullet and section.

4. **Map experience to the role**: for each JD signal identified in step 2, find the most relevant bullets, projects, and roles in the base resume. Score sections by relevance. Decide which bullets to keep, which to move up, and which to de-emphasize. Never remove a section entirely.

5. **Rewrite the summary**: write a new Summary section that reflects the JD's priorities and language. Mirror the JD's vocabulary where accurate. Do not copy the JD verbatim. Keep it to 3-5 sentences. Apply all sanitizing-text rules.

6. **Produce the company slug**: derive a short, lowercase, hyphen-separated slug from the company name. Examples: `stripe`, `github`, `totvs-labs`.

7. **Generate the output HTML**:
   - Path: `docs/resume/{company-slug}/felipe-ascari-resume.html`
   - Create the directory if it does not exist
   - Copy the `<style>` block verbatim from the base resume
   - Replace only the content: summary, bullet order, bullet emphasis
   - Do not add new sections or remove existing ones
   - The file must be self-contained: inline CSS, no external stylesheets or scripts

   The company slug is used only for the directory name, never for the filename itself. This keeps uploaded files neutral (the recipient sees `felipe-ascari-resume.pdf`, not `felipe-ascari-resume-stripe.pdf`).

8. **Sanitize all prose** before writing the file. Read every sentence against all rules in `.github/skills/sanitizing-text/SKILL.md`. This step is mandatory and must not be skipped. Common violations in CV prose:
   - Em-dashes (`—`) used as connectors: rewrite as two sentences or use a comma
   - Colons as prose connectors: rewrite using "including", "such as", or a new sentence
   - Forbidden AI words: `leverage`, `robust`, `seamless`, `holistic`, `empower`, `foster`, `streamline`
   - Hedging words: `actually`, `essentially`, `basically`, `clearly`, `obviously`
   - Sentences over 30 words: split them
   - Passive voice: rewrite in active voice

   Fix all violations before proceeding to Step 9.

9. **Validate and generate the PDF**: run the following command after writing the file:

```bash
mise run validate-pdf -- docs/resume/{company-slug}/felipe-ascari-resume.html
```

   If the command fails, report the error output and stop. Do not attempt to fix the HTML silently.

10. **Generate form answers** (if the user provided application questions): for each question, write a concise answer grounded in the tailored resume. Each answer must reference a specific role, project, or metric from the base resume. No vague claims.

## Output

- `docs/resume/{company-slug}/felipe-ascari-resume.html`: self-contained tailored resume
- `docs/resume/{company-slug}/felipe-ascari-resume.pdf`: PDF produced by `mise run validate-pdf`
- If form questions were provided: a numbered list of answers, one per question

## Constraints

- Never invent experience, metrics, or skills not present in the base resume
- Never change the CSS or visual structure of the resume — copy the `<style>` block verbatim from the base resume; changing font size, line-height, padding, or margins to make content fit is forbidden
- **The resume must fit on exactly one page.** If the content overflows, condense bullets (merge, shorten, or remove lower-priority ones) until it fits. Never expand the CSS to make room.
- The output HTML must be self-contained: no external files, no linked stylesheets
- All prose must pass sanitizing-text rules before the file is written
- Do not create more than one HTML file per run; one tailored file per company

## Common mistakes

| Mistake | Fix |
|---|---|
| Inventing a metric or achievement not in the base resume | Read the base resume again and use only what is there |
| Changing or extending the `<style>` block | Copy the `<style>` block verbatim; change nothing inside it |
| Adjusting font size, padding, or margins to make content fit | Condense or remove lower-priority bullets instead |
| Content overflows to a second page | Merge bullets, shorten sentences, or drop lower-priority items until everything fits on one page |
| Producing an HTML file that links to an external stylesheet | Inline all CSS; the file must be self-contained |
| Writing the summary in passive voice or using hedging words | Rewrite in active voice; apply sanitizing-text rules |
| Using em-dashes in generated prose | Replace with `:` or rewrite the sentence |
| Skipping `mise run validate-pdf` | Always run it after writing the file; it both validates and produces the PDF |
| Creating the output file at the wrong path | Path must be `docs/resume/{company-slug}/felipe-ascari-resume.html` |
| Answering form questions with generic claims | Every answer must reference a specific role, project, or number from the resume |
