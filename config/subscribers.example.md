# Subscriber configuration — example only

**This file contains fictitious placeholders, not actual subscribers.** Never put real email addresses, device tokens, private ntfy topics, authentication tokens, or recipient-to-household mappings in this public repository.

Actual subscriber settings belong in an access-controlled, private data source readable by the runtime.

| Subscriber ID | Delivery | Scope | Enabled | Verified consent |
| --- | --- | --- | --- | --- |
| example-owner | email | household | false | false |
| example-member | ntfy | own-mail-only | false | false |

A subscriber must explicitly opt in. `own-mail-only` routing requires a trusted private mapping and **high-confidence recipient identification**. A mailpiece with unclear recipient is not routed to an individual.
