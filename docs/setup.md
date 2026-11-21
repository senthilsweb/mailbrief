# Setup — OpenAI-managed MailBrief

## 1. Gmail

Connect Gmail in ChatGPT, then verify a Work event trigger for a *new message* matching USPS Informed Delivery digests. If event-based trigger configuration is unavailable for the account, that is a blocker; do not silently replace it with a polling service.

Match the sender address `USPSInformeddelivery@email.informeddelivery.usps.com` and subject `Your Daily Digest`. Actual USPS digests may contain **inline JPEG MIME parts** while `has_attachment=false`. Verify that the managed task can access their image pixels.

## 2. Skills

Load `SKILL.md` plus the referenced Markdown sub-skills into the managed task by a supported skill or file mechanism. A GitHub repository alone does not automatically install or activate skills in ChatGPT.

## 3. Runtime secrets

**Public GitHub:** no actual credentials or subscriber contact details.

**GitHub Actions Secrets:** suitable only for an Actions job that actually runs in GitHub Actions. They cannot be directly read by a ChatGPT-managed Work task.

**ChatGPT Work:** use its documented authorized app connections and, *if available in the current environment*, a supported secret-management or credential mechanism. Arbitrary `OPENAI_*` or `NTFY_*` environment variables are **not guaranteed** to be supported by Work. Never paste secret values into prompts, repository files or PRs.

Suggested *names* for a future adapter (not actual values):

- `NTFY_SERVER_URL`
- `NTFY_TOPIC`
- `NTFY_AUTH_TOKEN`
- `MAILBRIEF_SUBSCRIBER_CONFIG`

## 4. ntfy integration

Confirm the provider is **ntfy**. Set up protected topics with appropriate read/write access. Verify a supported outbound integration in ChatGPT Work before planning unattended delivery. If an HTTP-capable connector is absent, the no-code constraint may require a supported integration app or a change of delivery channel.

## 5. Persistent private state

Store subscriber opt-in, address/recipient mappings, message ID deduplication, delivery receipts and preferences in a supported private store. Do not store these in the public repository or assume chat history is an exactly-once ledger.

## 6. Activation gates

- [ ] Gmail event trigger works
- [ ] Inline MIME images readable
- [ ] Vision evaluation matches manually verified scans
- [ ] Private subscriber registry exists
- [ ] Durable processing ledger verified
- [ ] Authorized email sending verified, if used
- [ ] Authenticated ntfy push verified, if used
- [ ] No secret or private mail data leaked to repository

Until all applicable checks pass, run in preview/draft mode.
