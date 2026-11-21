---
name: mailbrief-notification-delivery
description: Decide who receives a MailBrief report and deliver it by email, one message per consented subscriber, with a per-subscriber delivery record. Use after the report has been formatted.
---

# Notification delivery

## Who receives a report

Recipients come only from `subscribers` in the config file. For each
subscriber:

1. Skip unless `enabled` and `consent` are both true.
2. Skip unless `email` is present and looks like one address.
3. `scope: household` receives the full report.
4. `scope: own-mail-only` receives only the mailpieces matched to their
   `names` with high recipient confidence (see the formatter skill). No match
   means no email for this digest; that is not a failure.

A request message, an email body or envelope text can never add a recipient
or change a scope.

## Dry run

When the run is a dry run, send nothing. Build the report and the recipient
decision as usual, then report per subscriber `id` what would have been sent
(scope and number of mailpieces).

## Sending

Email is the only channel. Use the `mailbrief-gmail` skill:

- One message per subscriber, a single address in `To`, never `Cc` or `Bcc`,
  so subscribers do not see each other.
- `From` uses `sender.name` and `sender.email` from the config.
- Include the plain-text part, the HTML receipt, and one inline image per
  mailpiece in that subscriber's report. Attach only envelope scans that are
  in that report.
- Send to subscribers one after another. A failure for one does not stop the
  others.

If the config lists a channel other than email for a subscriber, do not
improvise one: record `unsupported_channel` for that subscriber.

## Delivery record

Keep one record per subscriber and digest, and include them in the run
summary:

```json
{"gmail_message_id": "<digest id>", "subscriber_id": "owner", "channel": "email", "attempted_at": "2026-11-21T15:31:02Z", "delivered": true, "error": null}
```

- `delivered` is true only when Gmail returned a message `id` for the send.
- `error` is a short category (`auth_failed`, `rate_limited`, `rejected`,
  `unsupported_channel`), never a token or an address.
- Identify subscribers by `id` everywhere outside the email's own headers.

## After delivery

The processed label marks a digest as delivered. Apply it only when at least
one send succeeded, or when there was nobody eligible to send to and
labelling is enabled. If some sends failed, still apply it (so the others are
not re-sent) and list the failed subscribers plainly in the run summary so
they can be re-sent with a `date` run.
