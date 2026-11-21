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

## Approved HTML receipt layout

For email presentation, follow `templates/email-receipt.html` and `templates/README.md`:

- Layout: compact, mobile-first, separate cards, one per mailpiece.
- Include each corresponding exterior envelope scan as a small **private** thumbnail only when a safe authorized inline-image mechanism is actually supported; never host USPS scans publicly.
- Include sender and recipient as visibly supported, mark uncertain fields `Unknown` or `Unclear`.
- A household-level report goes only to subscribers with verified household-level consent.
- Treat template data as untrusted: HTML-escape text fields; never inject envelope text into markup.
- Reuse fixed template formatting for deterministic distribution. If dynamic rendering or inline images are unavailable, return a preview and a specific blocker rather than claiming production readiness.
