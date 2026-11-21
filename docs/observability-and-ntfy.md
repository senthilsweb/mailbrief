# Private notifications and observability

## Discovered configuration patterns (2026-11-21)

These findings are from the **private** repository `senthilsweb/my-agent-task-register` (not copied here). This public file deliberately contains **no credential values, subscriber records, addresses, message data or private infrastructure tokens**.

### ntfy

- Existing self-hosted Docker service: `home-lab/dockerized-apps/ntfy/`
- The Compose configuration advertises localhost as its base URL, and the environment uses `NTFY_AUTH_DEFAULT_ACCESS=deny-all`.
- The **public HTTPS FQDN was not found/verified**. Do not assume that `ntfy.senthilsweb.com` or `notification.senthilsweb.com` is the actual ingress.
- Use authenticated topic ACLs. A publisher should have write-only permission where supported; subscribers should have read-only access. Never use a public topic for mail metadata.
- An existing README contains credential-like text. Rotate any active credentials and move sensitive values out of repository-tracked files; audit history if they were ever pushed.

### OTLP

- Existing collector: `home-lab/dockerized-apps/otel/`, OTLP gRPC 4317 / HTTP 4318.
- At inspection, it had a **logs-only pipeline** to OpenObserve; sending MailBrief traces to the receiver would not make LangSmith or Arize traces appear without a traces pipeline/exporters.
- Arize configuration *names* are found in `home-lab/dockerized-apps/langflow/.env`: `ARIZE_API_KEY`, `ARIZE_SPACE_ID`, `ARIZE_COLLECTOR_ENDPOINT`. `jobmatch/.env` also contains an Arize project name.
- Arize AX documented HTTP trace endpoint: `https://otlp.arize.com/v1/traces`. Confirm required auth headers and the target space/project in Arize settings before export.
- A usable LangSmith API key was **not confirmed** in the inspected configuration. Do not assume the LangSmith trace interface accepts generic OTLP in the same format as Arize; check the currently supported ingestion/instrumentation mechanism.
- The existing collector config also contains what appears to be a hardcoded Basic authorization value. Replace with secret injection and rotate affected credentials if active.

### Proposed telemetry events (minimal, no PII)

```text
mailbrief.run.started
mailbrief.gmail.digest_found
mailbrief.vision.image_processed
mailbrief.report.generated
mailbrief.gmail.label_applied
mailbrief.notification.delivery_attempted
mailbrief.notification.delivery_result
mailbrief.run.completed
```

Suggested attributes: `service.name=mailbrief`, `agent.mode=event|date|range`, `mailpiece.count`, `vision.image.count`, `vision.unclear.count`, `notification.channel`, `delivery.success`, `error.type`, `duration_ms`. Use an opaque run ID; never emit raw sender/recipient names, home address, USPS images, Gmail IDs, tokens, headers or full model prompts/responses.

## Architectural limitation

This is a **Markdown-only, ChatGPT Work-managed** agent. Skills can describe spans and telemetry semantics, but do not gain an OTLP exporter or direct HTTP networking merely from Markdown instructions. Before claiming delivery to Arize/LangSmith, verify that Work exposes permitted instrumentation, a connector, or a webhook/HTTP bridge with secure secrets. If it does not, record the trace-like execution summary in a private store and leave OTLP export disabled. Any external collector bridge should be explicitly documented rather than hidden inside the skill.

References:
- https://docs.ntfy.sh/config/
- https://docs.ntfy.sh/publish/
- https://arize.com/docs/ax/observe/tracing-integrations-auto/opentelemetry-integrations-for-arize/opentelemetry-arize-otel
