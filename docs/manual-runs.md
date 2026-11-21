# Manual and historical runs

MailBrief supports **one date**, **inclusive date range**, or the normal **new-email event**. This is an instruction-level contract; it does not create a trigger by itself.

## Modes

| Mode | Parameters | Purpose |
| --- | --- | --- |
| `event` | message ID from Gmail event | Production notification |
| `date` | `YYYY-MM-DD` | Inspect USPS digest on that local calendar date |
| `range` | `YYYY-MM-DD` start and end | Replay all qualifying USPS digests in an inclusive period |

All dates use `America/New_York` for searching and display. Validate dates and require start <= end. Match both USPS sender metadata and subject. Use Gmail date search operators `after:YYYY/MM/DD before:YYYY/MM/DD` with **next-day exclusive** upper boundary. Gmail search date operators have timezone semantics that may differ from `America/New_York`; verify the email timestamp and the subject's displayed date after search, and use explicit epoch-second boundaries when exact timezone behavior is essential. If the requested date is absent or ambiguous, report that rather than shifting dates silently.

## Example prompts (ChatGPT / Work)

- `Run MailBrief in dry-run mode for 2026-11-20. Do not send email, push notifications, or apply labels.`
- `Run MailBrief for 2026-11-17 through 2026-11-20 inclusive. Return one summary per USPS digest and a cumulative count. Do not send or label anything.`
- `Run MailBrief for 2026-11-20. Apply the processed Gmail label only after successful analysis; do not notify subscribers.`

## Side-effect control

Default manual runs to `dry_run=true`, with **no delivery** and **no labeling**. A manual backfill should never resend historic notifications without explicit instruction and subscriber authorization. Dates do not themselves identify a unique Gmail message; if multiple legitimate digests match, analyze each separately and show date/message association.

## Labeling

The connected Gmail tool supports adding labels by name, creating missing labels if authorized. Apply `MailBrief/Processed` only to **successfully analyzed** messages, after all requested validation. Missing images or failed vision analysis should retain an unprocessed status and can optionally receive `MailBrief/NeedsReview`. Keep Gmail labels separate from the subscriber delivery ledger; processing and delivery are not the same event.

We have verified the available `apply_labels_to_emails` action in this account. It takes Gmail message IDs and label names; **no custom Python code or Gmail API script is needed** for an authorized agent with this connector. Whether a background task is allowed to modify Gmail without asking depends on the Work task's write authorization settings.

## API invocation: eligibility matters

**ChatGPT Plus Work tasks** support connected-app event triggers, but a generic API endpoint to invoke an arbitrary personal Plus task is **not established here**.

The official **Workspace Agents API trigger** is documented for eligible Business/Enterprise workspaces with a published Workspace Agent API channel and a scoped Workspace Agent access token. If eligible, use `scripts/trigger-workspace-agent.sh`. It queues an asynchronous run and returns a conversation URL/run ID rather than a synchronous digest. **Do not use an OpenAI Platform API key** with that endpoint. The script is optional, not the primary Plus workflow.

Reference: https://developers.openai.com/api/docs/guides/chatgpt/workspace-agents/trigger-runs

An entirely different option is a fresh OpenAI Platform Responses/Agents API implementation with uploaded skills, but it is separately billed and its agent would not automatically inherit ChatGPT's Gmail connection. It is not this repository's initial architecture.
