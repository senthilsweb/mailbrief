# Running MailBrief

## Automatically

`deployments/daily-digest.md` fires at 10:30 `America/New_York`, Monday to
Saturday. Each run processes every USPS digest from the last 3 days that does
not carry the `MailBrief/Processed` label, so a late digest is picked up the
next day and nothing is sent twice. Each run is capped at $0.50.

## With the script

`scripts/run-mailbrief.sh` wraps the API calls below. It needs `curl` and `jq`,
reads `ANTHROPIC_API_KEY` from the environment or a git-ignored `.env` at the
repository root, and takes the resource IDs from `claude-lock.json`.

```sh
scripts/run-mailbrief.sh date 2026-11-20
scripts/run-mailbrief.sh range 2026-11-20 2026-11-21
scripts/run-mailbrief.sh scheduled
```

It starts the run, waits for it (usually one to two minutes) and prints the
cost and the agent's run summary. The summary names senders and recipients
from your mail, so do not run the script where its output is logged publicly.

| Option | Effect |
| --- | --- |
| `--reset-labels` | Before the run, remove `MailBrief/Processed` and `MailBrief/NeedsReview` from the digests in the requested date or range, so they are sent again. Needs `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET` and `GMAIL_REFRESH_TOKEN` in the environment or `.env`. |
| `--no-wait` | Print the session id and return immediately. |

Every run is live: reports go to all enabled subscribers. With
`--reset-labels` they receive those days again.

## Through the API

The IDs come from `claude-lock.json`:

```sh
lock() { jq -r --arg k "$1" '.resources[$k].id' claude-lock.json; }
AGENT=$(lock ./agents/mailbrief.md)
ENVIRONMENT=$(lock ./environments/mailbrief.yaml)
VAULT=$(lock ./vaults/mailbrief.yaml)
STORE=$(lock ./memory_stores/mailbrief-config.yaml)
DEPLOYMENT=$(lock ./deployments/daily-digest.md)
```

Every request needs these headers:

```sh
H=(-H "x-api-key: $ANTHROPIC_API_KEY"
   -H "anthropic-version: 2026-10-21"
   -H "anthropic-beta: managed-agents-2026-04-01"
   -H "anthropic-workspace-id: $ANTHROPIC_WORKSPACE_ID"
   -H "content-type: application/json")
```

### Fire the standard daily run now

```sh
curl -fsS -X POST "https://api.anthropic.com/v1/deployments/$DEPLOYMENT/run" "${H[@]}"
```

### Run for a date or a range

```sh
curl -fsS https://api.anthropic.com/v1/sessions "${H[@]}" -d @- <<EOF
{
  "agent": "$AGENT",
  "environment_id": "$ENVIRONMENT",
  "vault_ids": ["$VAULT"],
  "title": "MailBrief 2026-11-20",
  "resources": [{"type": "memory_store", "memory_store_id": "$STORE", "access": "read_only"}],
  "budget": {"type": "limit", "max_list_cost": {"amount": "50", "currency": "USD"}},
  "initial_events": [{
    "type": "user.message",
    "content": [{"type": "text", "text": "Run MailBrief in mode: date 2026-11-20. Finish with the run summary."}]
  }]
}
EOF
```

Modes are `scheduled`, `date YYYY-MM-DD` and `range YYYY-MM-DD..YYYY-MM-DD`.
Every run sends the report and labels the digest; a digest that already has
the `MailBrief/Processed` label is skipped. Recipients always come from the
private config; a request cannot add any.

The response carries the session `id`. Read the result with:

```sh
curl -fsS "https://api.anthropic.com/v1/sessions/$SESSION_ID/events" "${H[@]}"
```

or watch it live with `ant beta:sessions connect $SESSION_ID`, or in the
Claude Console under Sessions.

### From GitHub

The "Run MailBrief on demand" workflow (`.github/workflows/cma-run.yml`) does
the same from the Actions tab or `gh workflow run cma-run.yml -f mode=date -f date=2026-11-20`.
