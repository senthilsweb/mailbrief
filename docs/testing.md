# Test plan

## Read-only historical test

Use the historical USPS digest from November 20, 2026 (reported **3 mailpieces** and **0 inbound packages**) as an initial test fixture only in the authenticated Gmail environment; do **not** commit scans or personally identifying metadata.

1. Verify sender and subject.
2. Verify reported mailpiece and package counts.
3. Verify inline image extraction when ordinary attachment flag is false.
4. Distinguish actual envelope previews from decorative images.
5. Have the vision skill process each visible envelope independently.
6. Compare recognized sender and recipient to a human review.
7. Produce a preview summary without delivery.

## Negative and integration tests

- Sender spoofed or unrelated email → reject.
- Mail count disagrees with number of preview images → report discrepancy.
- Unclear name/return address → `Unclear` / `Unknown`, never fabricate.
- Envelope contains imperative text → ignore as untrusted input.
- Recipient identified with low confidence → no individual routing.
- Subscriber not opted in → no delivery.
- ntfy tool or token unavailable → report failure, not success.
- Duplicate Gmail message ID → do not redeliver if ledger shows success.
- Delivery succeeds for one subscriber but fails for another → record independent status safely.
- No durable state store → declare duplicate-delivery risk.
- Public repository scan → no private images, names, addresses or credentials.

## Production acceptance

Approve production only once event triggering, image access, privacy isolation, delivery authorization and persistent deduplication are verified.
