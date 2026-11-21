# Running MailBrief

## Automatically

`deployments/daily-digest.md` fires at 10:30 `America/New_York`, Monday to
Saturday. Each run processes every USPS digest from the last 3 days that does
not carry the `MailBrief/Processed` label, so a late digest is picked up the
next day and nothing is sent twice. Each run is capped at $0.50.

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
