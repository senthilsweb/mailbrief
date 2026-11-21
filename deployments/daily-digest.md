---
name: mailbrief-daily-digest
agent: ../agents/mailbrief.md
environment_id: ../environments/mailbrief.yaml
# vault_ids takes IDs, not paths: this is the id of vaults/mailbrief.yaml in
# claude-lock.json.
vault_ids: [vlt_011ChGnDkcYC6jMaYsdzthS3]
# Like vault_ids, this takes the id (memory_stores/mailbrief-config.yaml in
# claude-lock.json): a path is only resolved for a bare list entry, which
# cannot carry access: read_only.
resources:
  - type: memory_store
    memory_store_id: memstore_0157XCPVUiJme9ePMRmtTAGL
    access: read_only
    instructions: Read config.yaml before doing anything else. It is the only source of recipients.
schedule:
  type: cron
  # USPS digests usually arrive in the morning, Monday to Saturday.
  expression: "30 10 * * 1-6"
  timezone: America/New_York
# Hard cap per run, in cents.
budget:
  type: limit
  max_list_cost: {amount: "50", currency: USD}
---

Run MailBrief in `scheduled` mode: process every qualifying USPS Informed
Delivery digest from the last 3 days that does not yet carry the processed
label, and send it to the subscribers in the config file. Finish with the run
summary.
