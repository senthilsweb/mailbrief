---
name: mailbrief-digest-formatter
description: Produce concise accessible daily USPS mail summaries with explicit uncertainty and no unnecessary private details.
---

# Digest Formatter

Use USPS-provided counts when available. Present any scan/count mismatch.

## Format

```text
USPS MailBrief — YYYY-MM-DD
Expected: 3 letters • 0 packages
1. From: [visible sender or Unknown] → To: [visible recipient or Unclear]
2. From: [visible sender or Unknown] → To: [visible recipient or Unclear]
3. From: [visible sender or Unknown] → To: [visible recipient or Unclear]
Envelope previews only; physical delivery is not confirmed.
```

- Keep push summaries short; when over channel length limits, show counts and a truncated list, not hidden content.
- Do not include street addresses, mailpiece images, tracking numbers or speculative categories in push notifications.
- Use `Unclear`, `Unknown` or `Not inspected` distinctly.
- Never present illustrative sample entries as actual observations.
- Produce a recipient-specific report only from **high-confidence** observed recipient names matched against private, consented subscriber mappings.
