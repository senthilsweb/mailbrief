#!/usr/bin/env bash
# OPTIONAL: Eligible Workspace Agents API channel only (not a generic Plus Task API).
# No Python or external SDK. Requires curl and jq.
# Example:
#   export WORKSPACE_AGENT_TRIGGER_ID='agtch_...'
#   export WORKSPACE_AGENT_ACCESS_TOKEN='...'
#   bash scripts/trigger-workspace-agent.sh --date 2026-11-20
#   bash scripts/trigger-workspace-agent.sh --from 2026-11-17 --to 2026-11-20
set -euo pipefail

usage() {
  printf 'Usage: %s (--date YYYY-MM-DD | --from YYYY-MM-DD --to YYYY-MM-DD)\n' "$0" >&2
  exit 2
}
[[ $# -ge 2 ]] || usage
mode='' start='' end=''
case "${1:-}" in
  --date) [[ $# -eq 2 ]] || usage; mode=date; start="$2"; end="$2";;
  --from) [[ $# -eq 4 && "${3:-}" == '--to' ]] || usage; mode=range; start="$2"; end="$4";;
  *) usage;;
esac

# Validate syntax and chronology (lexical comparison works with ISO date strings).
for value in "$start" "$end"; do
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo 'Expected YYYY-MM-DD' >&2; exit 2; }
done
[[ "$start" < "$end" || "$start" == "$end" ]] || { echo 'Start date must not exceed end date' >&2; exit 2; }

: "${WORKSPACE_AGENT_TRIGGER_ID:?Missing WORKSPACE_AGENT_TRIGGER_ID}"
: "${WORKSPACE_AGENT_ACCESS_TOKEN:?Missing WORKSPACE_AGENT_ACCESS_TOKEN}"
[[ "$WORKSPACE_AGENT_TRIGGER_ID" == agtch_* ]] || { echo 'Expected Workspace Agent API channel ID (agtch_...)' >&2; exit 2; }
command -v curl >/dev/null || { echo 'curl required' >&2; exit 2; }
command -v jq >/dev/null || { echo 'jq required' >&2; exit 2; }

# No customer data, tokens or secret topics should appear in logs or Git.
request="Run MailBrief mode=$mode for $start through $end inclusive (America/New_York). Use the connected Gmail account, review inline scans, return the digest, and DO NOT send, notify or label any messages. dry_run=true."
key="mailbrief-$mode-$start-$end-dryrun-v1"
body=$(jq -n --arg input "$request" --arg key "$key" '{conversation_key:$key,input:$input}')
curl --fail-with-body --silent --show-error \
  -X POST "https://api.chatgpt.com/v1/workspace_agents/$WORKSPACE_AGENT_TRIGGER_ID/trigger" \
  -H "Authorization: Bearer $WORKSPACE_AGENT_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "OpenAI-Beta: workspace_agent_runs=v1" \
  -H "Idempotency-Key: $key" \
  --data "$body"
printf '\n'
