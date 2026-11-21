#!/usr/bin/env bash
# Start a MailBrief run through the Claude Managed Agents API.
#
#   scripts/run-mailbrief.sh scheduled
#   scripts/run-mailbrief.sh date 2026-11-20
#   scripts/run-mailbrief.sh range 2026-11-20 2026-11-21
#
# Options (after the mode):
#   --reset-labels  First remove the MailBrief labels from the digests in the
#                   requested date or range, so they are picked up and sent
#                   again. Needs the three GMAIL_* values.
#   --no-wait       Print the session id and return without waiting.
#
# Requires curl and jq. Run from anywhere inside the repository.
# Reads ANTHROPIC_API_KEY (and GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET,
# GMAIL_REFRESH_TOKEN for --reset-labels) from the environment, or from a
# git-ignored .env file at the repository root. The workspace comes from
# ANTHROPIC_WORKSPACE_ID or, failing that, claude-lock.json.
#
# Every run is live: reports go to the subscribers in the private config.
set -euo pipefail

usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "error: $*" >&2; exit 1; }

command -v curl >/dev/null || die "curl is required"
command -v jq >/dev/null || die "jq is required"

root=$(cd "$(dirname "$0")/.." && pwd)
lockfile="$root/claude-lock.json"
[ -f "$lockfile" ] || die "claude-lock.json not found; deploy first (see README)"

# Values already in the environment win over .env.
from_env_file() {
  [ -f "$root/.env" ] || return 0
  grep -E "^$1=" "$root/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"'\r\n' || true
}
setting() { local v="${!1:-}"; [ -n "$v" ] || v=$(from_env_file "$1"); printf %s "$v"; }

date_re='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
mode="${1:-}"; [ -n "$mode" ] || usage; shift
start="" end=""
case "$mode" in
  scheduled) what="scheduled" ;;
  date)
    start="${1:-}"; end="$start"; shift || true
    [[ "$start" =~ $date_re ]] || die "date needs YYYY-MM-DD"
    what="date $start" ;;
  range)
    start="${1:-}"; end="${2:-}"; shift 2 || true
    [[ "$start" =~ $date_re && "$end" =~ $date_re ]] || die "range needs two dates, YYYY-MM-DD YYYY-MM-DD"
    [[ ! "$start" > "$end" ]] || die "the first date must not be after the second"
    what="range $start..$end" ;;
  *) usage ;;
esac

reset_labels=false wait=true
for arg in "$@"; do
  case "$arg" in
    --reset-labels) reset_labels=true ;;
    --no-wait) wait=false ;;
    *) die "unknown option: $arg" ;;
  esac
done

api_key=$(setting ANTHROPIC_API_KEY)
[ -n "$api_key" ] || die "ANTHROPIC_API_KEY is not set (environment or .env)"
workspace=$(setting ANTHROPIC_WORKSPACE_ID)
[ -n "$workspace" ] || workspace=$(jq -r '.origin.workspace_id // empty' "$lockfile")
[ -n "$workspace" ] || die "ANTHROPIC_WORKSPACE_ID is not set"

lock() {
  local id; id=$(jq -r --arg k "$1" '.resources[$k].id // empty' "$lockfile")
  [ -n "$id" ] || die "$1 is not in claude-lock.json"
  printf %s "$id"
}
agent=$(lock ./agents/mailbrief.md)
environment=$(lock ./environments/mailbrief.yaml)
vault=$(lock ./vaults/mailbrief.yaml)
store=$(lock ./memory_stores/mailbrief-config.yaml)

# --- optional: clear the MailBrief labels so the digests are sent again ------
if $reset_labels; then
  [ "$mode" != scheduled ] || die "--reset-labels needs a date or a range"
  client_id=$(setting GMAIL_CLIENT_ID)
  client_secret=$(setting GMAIL_CLIENT_SECRET)
  refresh_token=$(setting GMAIL_REFRESH_TOKEN)
  [ -n "$client_id" ] && [ -n "$client_secret" ] && [ -n "$refresh_token" ] \
    || die "--reset-labels needs GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET and GMAIL_REFRESH_TOKEN"

  token=$(curl -sS https://oauth2.googleapis.com/token \
    -d "client_id=$client_id" -d "client_secret=$client_secret" \
    -d "refresh_token=$refresh_token" -d "grant_type=refresh_token" | jq -r '.access_token // empty')
  [ -n "$token" ] || die "could not mint a Gmail token; re-create GMAIL_REFRESH_TOKEN (see README)"
  gmail=https://gmail.googleapis.com/gmail/v1/users/me
  auth="Authorization: Bearer $token"

  label_ids=$(curl -sS "$gmail/labels" -H "$auth" \
    | jq -c '[.labels[] | select(.name == "MailBrief/Processed" or .name == "MailBrief/NeedsReview") | .id]')
  if [ "$label_ids" = "[]" ]; then
    echo "No MailBrief labels exist yet; nothing to reset."
  else
    # Search one day wider on each side, then keep digests whose subject date
    # is checked by the agent itself. Gmail's date operators use its own day
    # boundaries, so a narrow search can miss a morning digest.
    day_shift() { date -u -j -v"$2"d -f %Y-%m-%d "$1" +%Y/%m/%d 2>/dev/null || date -u -d "$1 $2 day" +%Y/%m/%d; }
    after=$(day_shift "$start" -1)
    before=$(day_shift "$end" +2)
    ids=$(curl -sS -G "$gmail/messages" -H "$auth" \
      --data-urlencode "q=from:USPSInformeddelivery@email.informeddelivery.usps.com subject:\"Your Daily Digest\" after:$after before:$before" \
      --data-urlencode "maxResults=50" | jq -r '.messages[]?.id')
    count=0
    for id in $ids; do
      # Keep only digests whose own date (New York time) is inside the request.
      day=$(curl -sS "$gmail/messages/$id?format=minimal" -H "$auth" \
        | jq -r '.internalDate | tonumber / 1000 | floor')
      day=$(TZ=America/New_York date -r "$day" +%Y-%m-%d 2>/dev/null || TZ=America/New_York date -d "@$day" +%Y-%m-%d)
      [[ ! "$day" < "$start" && ! "$day" > "$end" ]] || continue
      curl -sS -o /dev/null -X POST "$gmail/messages/$id/modify" -H "$auth" \
        -H 'Content-Type: application/json' -d "{\"removeLabelIds\": $label_ids}"
      count=$((count + 1))
    done
    echo "Cleared MailBrief labels on $count digest(s) from $start to $end."
  fi
fi

# --- start the session --------------------------------------------------------
headers=(-H "x-api-key: $api_key"
         -H "anthropic-version: 2026-10-21"
         -H "anthropic-beta: managed-agents-2026-04-01"
         -H "anthropic-workspace-id: $workspace"
         -H "content-type: application/json")

body=$(jq -n --arg agent "$agent" --arg env "$environment" --arg vault "$vault" \
  --arg store "$store" --arg what "$what" '{
    agent: $agent,
    environment_id: $env,
    vault_ids: [$vault],
    title: ("MailBrief " + $what),
    resources: [{type: "memory_store", memory_store_id: $store, access: "read_only"}],
    budget: {type: "limit", max_list_cost: {amount: "50", currency: "USD"}},
    initial_events: [{type: "user.message", content: [{type: "text",
      text: ("Run MailBrief in mode: " + $what + ". Finish with the run summary.")}]}]
  }')

session=$(curl -fsS https://api.anthropic.com/v1/sessions "${headers[@]}" -d "$body" | jq -r '.id')
[ -n "$session" ] && [ "$session" != null ] || die "the API did not return a session id"
echo "Started $session ($what)"
$wait || exit 0

# --- wait and print the run summary -------------------------------------------
deadline=$((SECONDS + 600))
status=running
while [ "$status" = running ] && [ $SECONDS -lt $deadline ]; do
  sleep 10
  status=$(curl -fsS "https://api.anthropic.com/v1/sessions/$session" "${headers[@]}" | jq -r '.status')
done
[ "$status" != running ] || die "still running after 10 minutes; check session $session in the Console"

curl -fsS "https://api.anthropic.com/v1/sessions/$session" "${headers[@]}" \
  | jq -r '"Finished: status=\(.status), list cost=\((.usage.list_cost.amount // "0" | tonumber) / 100) USD"'
echo
# The run summary is the agent's last message. It names senders and recipients
# from your mail, so do not run this script where its output is logged publicly.
curl -fsS "https://api.anthropic.com/v1/sessions/$session/events?limit=1000" "${headers[@]}" \
  | jq -r '[.data[] | select(.type == "agent.message")] | last | .content[]? | select(.type == "text") | .text'
