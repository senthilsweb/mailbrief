# How MailBrief is put together

Step-by-step setup is in the [README](../README.md). This page explains what
the files become and how the moving parts fit.

## Resources

| File | Resource |
| --- | --- |
| `agents/mailbrief.md` | Coordinator agent (Gmail, formatting, delivery) |
| `agents/mailbrief-vision.md` | Read-only envelope reader the coordinator delegates to |
| `skills/*/SKILL.md` | Four skills in the agentskills.io layout |
| `environments/mailbrief.yaml` | Sandbox; egress limited to Google OAuth and Gmail |
| `vaults/mailbrief.yaml` | Vault holding the Gmail OAuth client and refresh token |
| `memory_stores/mailbrief-config.yaml` | Private store holding `config.yaml`, mounted read-only |
| `deployments/daily-digest.md` | Daily schedule and the message that starts each run |

`ant apply` syncs these files to the Claude Developer Platform and records
the resulting IDs in `claude-lock.json`, which is committed.

`vault_ids` and the config store's `memory_store_id` in
`deployments/daily-digest.md` take IDs, not paths, which is why a first
deploy is done in two passes.

## Deploy workflow

`.github/workflows/cma-deploy.yml` plans on pull requests and, on a merge to
`main` or a manual run:

1. checks that the Gmail secrets can still mint an access token;
2. applies the files;
3. copies the three Gmail secrets into the vault;
4. copies `MAILBRIEF_CONFIG_YAML` into the config store;
5. opens a pull request for `claude-lock.json` if it changed.

Secrets: `ANTHROPIC_API_KEY`, `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`,
`GMAIL_REFRESH_TOKEN`, `MAILBRIEF_CONFIG_YAML`. Variable:
`ANTHROPIC_WORKSPACE_ID`.

The agents never read GitHub. A changed secret reaches them only when this
workflow runs.

## Gmail access

The agent has no Gmail connector. At the start of a run it exchanges the
refresh token for a one-hour access token and then calls the Gmail REST API
with `curl`, following `skills/mailbrief-gmail/SKILL.md`. The client secret
and refresh token never enter the sandbox: it holds placeholders, and the
real values are substituted only on requests to `oauth2.googleapis.com`. The
one-hour access token does exist inside the sandbox for the length of the
run.

## Tracing

Traces go to an observability backend through an organisation-level
OpenTelemetry destination (Console → Settings → OpenTelemetry). It is not
part of these files and an organisation admin adds it once. Spans carry
`service.name` = `claude-platform`; group by `anthropic.session.id` to see
one run.
