# MailBrief

**MailBrief** reads the daily USPS Informed Delivery email, looks at each
envelope scan, and emails a short report of who is sending mail to whom. It
runs on [Claude Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview)
and is defined entirely in Markdown and YAML: no application code.

USPS Informed Delivery previews show envelope exteriors, **not letter
contents**. They are previews of expected mail, not proof of delivery.

> **Gmail only.** MailBrief reads and sends mail through the Gmail REST API,
> so the mailbox that receives the USPS digests must be a Gmail or Google
> Workspace account. Subscribers can be on any email provider. To use a
> different mailbox provider (Outlook, iCloud, Fastmail, ...), rewrite
> [skills/mailbrief-gmail/SKILL.md](skills/mailbrief-gmail/SKILL.md) for that
> provider's API, and change the allowed hosts in
> [environments/mailbrief.yaml](environments/mailbrief.yaml) and the credential
> names in the deploy workflow to match.

## How it works

![MailBrief architecture: an API call or the built-in schedule starts a run on Claude Managed Agents. Inside an isolated sandbox the mailbrief coordinator and the read-only mailbrief-vision agent work together. The schedule, four skills, config store and vault sit on the platform outside the sandbox. The coordinator talks to the Gmail API, which delivers one email to each subscriber. Traces go out over OTLP. GitHub Actions deploys from the repo. Dashed boxes are extension points that are not built yet: MCP tools for a database, a push alert, evals, and other mailboxes.](docs/images/mailbrief-architecture.png)

Solid lines are built and running. Dashed boxes are extension points that are not built yet.

- **Two agents.** The coordinator handles Gmail and delivery. The vision
  agent only reads image files; it has no shell, no network and no way to
  send anything, so text on an envelope cannot steer a send.
- **What runs where.** The agents' commands run in a fresh sandbox for each
  run. The schedule, the skills, the config store and the vault sit on the
  platform, outside the sandbox: skills and config are made visible inside as
  files, and vault secrets are added to a request only after it leaves the
  sandbox. GitHub Actions is used only to deploy; the daily run does not
  depend on it.
- **Traces.** Every run is sent as a trace to an OTLP backend, set once at
  the organisation level.
- **Dedup by label.** A processed digest gets the `MailBrief/Processed` Gmail
  label and is skipped afterwards, in every kind of run.
- **Private data stays private.** Subscribers and the sender live in a config
  file kept in a GitHub secret and a private store; credentials live in a
  vault. Neither is in this repository.

## Set it up for your own mailbox

You need a Gmail account signed up for
[USPS Informed Delivery](https://www.usps.com/manage/informed-delivery.htm),
an [Anthropic Console](https://platform.claude.com) account with Managed
Agents, a GitHub account, and the [`gh`](https://cli.github.com) CLI.

### 1. Fork and clone

```sh
gh repo fork senthilsweb/mailbrief --clone
cd mailbrief
```

The IDs in `claude-lock.json`, and the two IDs written into
`deployments/daily-digest.md`, belong to the original deployment. Delete the
lock file now; step 6 recreates everything in your own workspace.

```sh
git rm claude-lock.json
```

### 2. Anthropic API key

In the Console, create an API key and note the ID of the workspace you want
MailBrief in (`wrkspc_...`, shown in the workspace's settings).

### 3. Google OAuth client

1. In the [Google Cloud console](https://console.cloud.google.com), create a
   project and enable the **Gmail API** (APIs & Services → Library).
2. Open **Google Auth Platform** (APIs & Services → OAuth consent screen).
   Choose **External** and fill in the app name and your email.
3. Under **Audience**, click **Publish app** so the status is **In
   production**. In "Testing", Google expires the refresh token after 7 days
   and MailBrief stops working. Verification is not needed for your own
   account.
4. Under **Clients**, create a client of type **Web application** and add the
   authorised redirect URI `https://developers.google.com/oauthplayground`.
   Copy the **client ID** and **client secret**.

### 4. Mint the Gmail refresh token

1. Open the [OAuth Playground](https://developers.google.com/oauthplayground).
2. Click the gear icon, tick **Use your own OAuth credentials**, and paste the
   client ID and secret.
3. In **Input your own scopes**, enter
   `https://www.googleapis.com/auth/gmail.modify` and click **Authorize APIs**.
   That one scope covers reading, labelling and sending; it cannot
   permanently delete mail.
4. Sign in with the mailbox that receives the USPS digests. On the
   "Google hasn't verified this app" page, choose **Advanced** and continue.
5. Click **Exchange authorization code for tokens** and copy the **Refresh
   token** (it starts with `1//`).

Check the three values before going further. This is the same exchange the
agent makes at the start of every run:

```sh
curl -s https://oauth2.googleapis.com/token \
  -d "client_id=$GMAIL_CLIENT_ID" \
  -d "client_secret=$GMAIL_CLIENT_SECRET" \
  -d "refresh_token=$GMAIL_REFRESH_TOKEN" \
  -d "grant_type=refresh_token" | jq '{ok: (.access_token != null), scope, error}'
```

`ok` should be `true` and `scope` should include `gmail.modify`. The deploy
workflow repeats this check and fails early if the token has stopped working.

### 5. Write your config

```sh
mkdir -p private
cp config/mailbrief.example.yaml private/config.yaml
```

Edit `private/config.yaml`: set `sender.email` to the Gmail address from
step 4, set your `timezone`, and list your subscribers. `private/` is
git-ignored. A subscriber is emailed only when `enabled` and `consent` are
both true.

### 6. GitHub secrets and first deploy

```sh
gh secret set ANTHROPIC_API_KEY
gh secret set GMAIL_CLIENT_ID
gh secret set GMAIL_CLIENT_SECRET
gh secret set GMAIL_REFRESH_TOKEN
gh secret set MAILBRIEF_CONFIG_YAML < private/config.yaml
gh variable set ANTHROPIC_WORKSPACE_ID --body wrkspc_...
```

The first deploy has to happen in two passes, because the schedule refers to
the vault and the config store by ID and those IDs do not exist yet. From
your machine, with the [`ant` CLI](https://platform.claude.com/docs/en/api/anthropic-cli)
(2.x) signed in to the same workspace:

```sh
# Pass 1: everything except the schedule
ant apply agents environments vaults memory_stores skills

# Put your own IDs into the schedule
jq -r '.resources["./vaults/mailbrief.yaml"].id, .resources["./memory_stores/mailbrief-config.yaml"].id' claude-lock.json
#   -> set vault_ids and memory_store_id in deployments/daily-digest.md

git add -A && git commit -m "Deploy MailBrief to my workspace" && git push
```

The push to `main` runs the deploy workflow, which creates the schedule,
loads the Gmail credentials into the vault, and copies your config into the
config store. After that, every merge to `main` redeploys.

When a deploy changes a resource, the workflow opens a small pull request
that updates `claude-lock.json`. Merge it, so the next deploy starts from the
current state. For that to work, tick **Allow GitHub Actions to create and
approve pull requests** under Settings → Actions → General.

### 7. Try it

Run a recent date from your machine:

```sh
scripts/run-mailbrief.sh date 2026-11-20
```

or use "Run MailBrief on demand" from the Actions tab. [docs/api.md](docs/api.md)
covers the script's options and the raw API calls. The report arrives within a
couple of minutes and the digest gets the `MailBrief/Processed` label.

## Day-to-day

- **Schedule:** 10:30 `America/New_York`, Monday to Saturday; change it in
  [deployments/daily-digest.md](deployments/daily-digest.md). Each run is
  capped at $0.50 and typically costs a few cents.
- **Change subscribers:** update the `MAILBRIEF_CONFIG_YAML` secret, then run
  the deploy workflow from the Actions tab. No agent change is involved.
- **Re-send a day:** `scripts/run-mailbrief.sh date YYYY-MM-DD --reset-labels`
  clears the label and runs that date again.
- **Refresh token stopped working:** repeat step 4, update
  `GMAIL_REFRESH_TOKEN`, and run the deploy workflow.

## Files

- [agents/](agents): the two agents (YAML frontmatter is the config, the body is the system prompt).
- [skills/](skills): `mailbrief-gmail`, `mailbrief-vision`, `mailbrief-digest-formatter`, `mailbrief-notification-delivery`, each a directory with a `SKILL.md` ([agentskills.io](https://agentskills.io) layout).
- [deployments/daily-digest.md](deployments/daily-digest.md): the schedule and the message that starts each run.
- [environments/](environments), [vaults/](vaults), [memory_stores/](memory_stores): sandbox, credential container and config store.
- [config/mailbrief.example.yaml](config/mailbrief.example.yaml): config schema with **fictional** values.
- [.github/workflows/](.github/workflows): deploy on merge, and run on demand.
- [scripts/run-mailbrief.sh](scripts/run-mailbrief.sh): start a run from your machine.
- [docs/](docs): [how it is put together](docs/setup.md), [API calls](docs/api.md), [test plan](docs/testing.md).

## Security notes

- No addresses, subscriber lists, scan images, tokens or real mail content
  belong in this repository. `.env` and `private/` are git-ignored.
- Workflow logs are public on a public repository. The workflows never print
  secrets (GitHub masks them) and never print the agent's output, so names
  from your mail do not appear there. Keep it that way if you change them.
- The Gmail client secret and refresh token never enter the agent's sandbox.
  A one-hour access token does, for the length of a run, in a sandbox that
  can reach only Google's OAuth and Gmail hosts.

## License

No license is granted by default; add a LICENSE file if you want to permit reuse.
