---
name: mailbrief-digest-formatter
description: Turn the vision records for one USPS digest into the MailBrief report, as plain text and as the HTML receipt email. Use after envelope images have been classified and before delivery.
---

# Digest formatter

Build one data record per digest, then render it twice: plain text and HTML.
The record is the single source for both.

## Data record

```json
{
  "display_date": "FRIDAY, NOVEMBER 20, 2026",
  "preheader": "3 incoming letters and 0 packages",
  "mailpiece_count": "03",
  "package_count": "00",
  "scan_count": "03",
  "mailpieces": [
    {"number": "01", "sender": "Northstar Auto Services", "recipient": "Alex Example", "thumbnail_src": "cid:mailbrief-01"}
  ]
}
```

- `mailpiece_count` and `package_count` are what USPS reported in the email;
  write `--` when a count is unknown.
- `scan_count` is the number of images accepted as `mailpiece_preview`. It
  can differ from `mailpiece_count`; show both as they are.
- `mailpieces` holds only accepted previews, in image order, numbered from 01.
  `thumbnail_src` is `cid:mailbrief-NN` for the matching inline image.
- Use `Unknown` when no sender is visible, `Unclear` when a name is obscured,
  `Not inspected` when the image could not be read. Keep them distinct.
- The names in the example are fictional. Never carry example values into a
  real report.

For an `own-mail-only` subscriber, build a separate record that keeps only
mailpieces whose recipient was read with `high` confidence and matches one of
the subscriber's `names`, renumbered from 01, with `scan_count` set to that
subset. If nothing matches, that subscriber gets no email for this digest.

## Subject line

One subject per email, in title case, built from the same record:

```text
Your USPS Mail Preview for Friday, November 20, 2026: 3 Mailpieces, 0 Packages
```

- The date is the digest's date in the config timezone, written out in full.
- Use the USPS-reported counts. Write `1 Mailpiece` and `1 Package` in the
  singular. Leave a count out when it is unknown.
- When USPS reports no mail: `Your USPS Mail Preview for Friday, November 20, 2026: No Mail Expected`.
- For an `own-mail-only` subscriber, count only their mailpieces:
  `Your USPS Mail Preview for Friday, November 20, 2026: 2 Mailpieces for You`.
- Plain ASCII only, and no sender or recipient names in the subject.

## Plain text

```text
Your USPS Mail Preview for Friday, November 20, 2026
Expected: 3 letters, 0 packages (3 scans)
1. From: Northstar Auto Services -> To: Alex Example
2. From: Unknown -> To: Unclear
Envelope previews only; physical delivery is not confirmed.
```

Add one line when scans and the USPS count disagree, for example
`USPS reported 4 mailpieces; 3 scans were available.`

## HTML

Fill `assets/email-receipt.html` in this skill's directory. It is a fixed
layout: change nothing but the placeholders.

- Replace `{{display_date}}`, `{{preheader}}`, `{{mailpiece_count}}`,
  `{{package_count}}`, `{{scan_count}}`.
- Repeat the block between `{{#mailpieces}}` and `{{/mailpieces}}` once per
  mailpiece, filling `{{number}}`, `{{sender}}`, `{{recipient}}`,
  `{{thumbnail_src}}`, and remove the two marker lines.
- Keep the `{{^mailpieces}}...{{/mailpieces}}` paragraph only when there are
  no mailpieces; otherwise delete it together with its markers.
- HTML-escape every inserted text value (`&`, `<`, `>`, `"`, `'`). Names come
  from envelope scans and must never be able to add markup.
- `thumbnail_src` is always a `cid:` reference to an image attached to the
  same email. No remote URLs, no `data:` URLs.
- Add nothing else: no tracking pixels, scripts, forms, external fonts or
  extra commentary.

After rendering, check that no `{{` remains in the file.

`references/render-contract.md` has the design background and
`assets/mock-preview.html` a fictional rendered example.
