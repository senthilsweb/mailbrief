# Setup: MailBrief on Claude Managed Agents

MailBrief runs as two managed agents. Everything in this repository is
Markdown or YAML; the `ant` CLI syncs it to the Claude Developer Platform.

## What gets created

| File | Resource |
| --- | --- |
| `agents/mailbrief.md` | Coordinator agent (Gmail, formatting, delivery) |
| `agents/mailbrief-vision.md` | Read-only envelope reader the coordinator delegates to |
| `skills/*/SKILL.md` | Four skills in the agentskills.io layout |
| `environments/mailbrief.yaml` | Sandbox; egress limited to Google OAuth and Gmail |
| `vaults/mailbrief.yaml` | Vault holding the Gmail OAuth client and refresh token |
| `memory_stores/mailbrief-config.yaml` | Private store holding `config.yaml`, mounted read-only |
| `deployments/daily-digest.md` | Daily schedule and the message that starts each run |

`claude-lock.json` records the IDs. Commit it.

## One-time prerequisites

1. **Anthropic.** An API key and the ID of the workspace MailBrief lives in.
2. **Google.** A Google Cloud project with the Gmail API enabled, an OAuth
   client of type "Web application", the app published ("In production"), and
   a refresh token for the mailbox that receives the USPS digests with the
   scope `https://www.googleapis.com/auth/gmail.modify`.
3. **Config.** Copy `config/mailbrief.example.yaml`, fill in the sender and
   subscribers, and keep it out of git (the `private/` folder is ignored).

## GitHub configuration

Secrets:

| Secret | Value |
| --- | --- |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `GMAIL_CLIENT_ID` | Google OAuth client ID |
| `GMAIL_CLIENT_SECRET` | Google OAuth client secret |
| `GMAIL_REFRESH_TOKEN` | Refresh token for the mailbox |
| `MAILBRIEF_CONFIG_YAML` | The whole private config file |

Variable: `ANTHROPIC_WORKSPACE_ID` (for example `wrkspc_...`).

## Deploying

`.github/workflows/cma-deploy.yml` plans on pull requests and applies on a
merge to `main`. After applying it copies the Gmail secrets into the vault and
the config into the config store, so changing a subscriber means updating the
`MAILBRIEF_CONFIG_YAML` secret and re-running the workflow.

From a laptop:

```sh
ant apply --dry-run agents environments vaults memory_stores skills deployments
ant apply agents environments vaults memory_stores skills deployments
```

`vault_ids` in `deployments/daily-digest.md` takes the vault's ID, not a
path. After the first apply, copy the ID from `claude-lock.json` into that
field and apply again.

## How Gmail access works

The agent has no Gmail connector. At the start of a run it exchanges the
refresh token for a one-hour access token and then calls the Gmail REST API
with `curl`. The client secret and refresh token never enter the sandbox: it
holds placeholders, and the real values are substituted only on requests to
`oauth2.googleapis.com`. The one-hour access token does exist inside the
sandbox for the length of the run.

## Going live

Keep `dry_run: true` in the config until a dry run of a real digest reads the
envelopes correctly. Then set `dry_run: false` with a single test subscriber,
confirm the email, and only then add the household.

## Tracing

Traces go to Arize through an organisation-level OpenTelemetry destination
(Console → Settings → OpenTelemetry, or the Admin API). It is not part of
these files and needs an organisation admin to add it once.
