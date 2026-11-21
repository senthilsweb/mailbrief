---
name: mailbrief-notification-delivery
description: Deliver approved MailBrief reports to explicitly consented recipients through supported Gmail or ntfy integrations.
---

# Notification Delivery

## Preconditions

- Subscriber is verified, opted in, enabled and authorized for the report's scope.
- Delivery tool is genuinely available and its permission/approval requirements are satisfied.
- A supported private configuration supplies the destination; public repository examples are not destinations.
- Delivery contains the minimum information appropriate for the channel.
- A private durable ledger is recommended to prevent duplicate sends and track partial failures.

## Email

Use an authorized Gmail send tool only. Do not assume the ability to send unattended; some deployments require per-action approval. Never CC multiple subscribers when that would reveal addresses or disallowed content.

## ntfy push

Preferred provider: ntfy (https://ntfy.sh), **subject to confirmation** that this is the requested service.

Publishing requires a supported authorized connector, HTTP action, or other approved integration; writing a URL into a Markdown skill **does not send a push**. Store a protected topic, authentication and any secret URL **only in a private runtime secret store**. Do not publish mail details to an open, guessable topic.

The adapter needs, at minimum:
- server endpoint
- private topic
- authentication credential / permitted publishing mechanism
- verified audience scope

If no supported publishing mechanism or secret injection exists in ChatGPT Work, return `ntfy_delivery_unavailable` and provide a safe setup blocker rather than claiming success. GitHub Actions Secrets do not automatically transfer to ChatGPT Work.

## Report status

Capture `channel`, `recipient_id` (not raw address in public logs), `attempted_at`, `delivered`, and safe error category in private storage.

Only mark `delivered=true` on success returned from the actual delivery integration. Never print bearer tokens or full subscriber lists.

## Household HTML receipt

Use `templates/email-receipt.html` as the email presentation template. Each authorized household subscriber receives an **individual** email (not group To/CC). Envelope thumbnails must be authenticated/embedded safely; do not expose public image URLs. Include a plain-text fallback. MIME CID construction is **not yet confirmed** for this Gmail integration. Never send a preview automatically; respect `dry_run=true`.

## Gmail dispatcher

For deterministic household email delivery, hand off to `agents/dispatcher/SKILL.md`. Do not use free-form model decisions to select recipients or rewrite the prepared email. Verify private allowlist and authorization, then send one identical approved receipt per recipient, tracking provider acceptance independently. Do not equate Gmail send success with physical delivery to an inbox.
