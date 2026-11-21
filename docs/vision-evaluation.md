# Vision extraction acceptance test

Date: November 20, 2026 (USPS digest in the authorized Gmail account).

## Observations (non-sensitive)

- USPS message body reports **3 mailpieces** and **0 inbound packages**.
- Gmail attachment metadata reports `has_attachment=false`, but **three inline JPEG MIME images** are available.
- All three original inline envelope scans were retrieved and visually inspected.
- Sender and recipient names were legible in all three previews, including a handwritten recipient address and two printed recipient labels.
- Two scanned pieces were addressed to the same person; one was addressed to a different person.
- No notification was sent and no Gmail label was changed during the test.

This record intentionally omits real people's names, sender details, mailing addresses, actual scans and Gmail message IDs. Do **not** add private envelope content to a public repo.

## Limits

This is a successful **single-day functional test**, not a statistical accuracy evaluation. Further testing should include unreadable scans, multiple destinations, missing images, ambiguous recipients, duplicates and forwarded/spoofed emails. Actual physical delivery cannot be inferred from USPS previews.
