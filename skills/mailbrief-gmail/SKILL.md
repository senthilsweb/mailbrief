---
name: mailbrief-gmail
description: Read, label and send Gmail through the Gmail REST API with curl. Use for minting the access token, finding USPS Informed Delivery digests, saving their inline images, applying labels and sending the report email.
---

# Gmail over REST

All Gmail access goes through `curl` in the shell. The sandbox can reach only
`oauth2.googleapis.com` and `gmail.googleapis.com`.

Three environment variables hold the OAuth client: `GMAIL_CLIENT_ID`,
`GMAIL_CLIENT_SECRET`, `GMAIL_REFRESH_TOKEN`. Inside the sandbox they are
opaque placeholders; the real values are swapped in only on requests to
`oauth2.googleapis.com`. Pass them to curl exactly as they are. Do not print,
URL-encode, trim or otherwise transform them, or the swap will not happen.

Write every API response to a file with `-o` and read fields with `jq`.
Message JSON is large; never print a whole response.

## 1. Mint an access token (once per run)

```bash
mkdir -p /workspace/run
curl -sS https://oauth2.googleapis.com/token \
  -d "client_id=$GMAIL_CLIENT_ID" \
  -d "client_secret=$GMAIL_CLIENT_SECRET" \
  -d "refresh_token=$GMAIL_REFRESH_TOKEN" \
  -d "grant_type=refresh_token" \
  -o /workspace/run/token.json
jq -r '.access_token // empty' /workspace/run/token.json > /workspace/run/access_token
jq '{ok: (.access_token != null), scope, expires_in, error, error_description}' /workspace/run/token.json
```

The token lasts about an hour. If `ok` is false, stop the run and report the
`error` field; nothing else can work. Use the token from the file in later
calls and never echo it:

```bash
AUTH="Authorization: Bearer $(cat /workspace/run/access_token)"
API=https://gmail.googleapis.com/gmail/v1/users/me
```

Shell variables do not survive between tool calls; set `AUTH` and `API` at
the top of each command.

## 2. Find digests

```bash
curl -sS -G "$API/messages" -H "$AUTH" \
  --data-urlencode 'q=from:USPSInformeddelivery@email.informeddelivery.usps.com subject:"Your Daily Digest" newer_than:3d' \
  --data-urlencode 'maxResults=20' -o /workspace/run/list.json
jq -r '.messages[]?.id' /workspace/run/list.json
```

For a date or range, replace `newer_than:3d` with `after:YYYY/MM/DD
before:YYYY/MM/DD`, where `before` is the day after the last wanted day.
Gmail's date operators use its own day boundaries, so confirm each message's
real date from `internalDate` (epoch milliseconds) in the config timezone and
drop messages outside the request. If a requested date has no digest, say so;
do not shift to a neighbouring day.

## 3. Read one message

```bash
ID=<message id>
mkdir -p /workspace/run/$ID
curl -sS "$API/messages/$ID?format=full" -H "$AUTH" -o /workspace/run/$ID/message.json

# Headers needed to qualify the sender, plus current labels
jq -r '.payload.headers[] | select(.name|test("^(From|Subject|Date|Authentication-Results)$";"i")) | "\(.name): \(.value)"' /workspace/run/$ID/message.json
jq -c '{internalDate, labelIds}' /workspace/run/$ID/message.json

# Every MIME part, at any depth
jq -r '[.payload | recurse(.parts[]?)] | .[] | [.partId, .mimeType, (.filename // ""), (.body.size|tostring), (.body.attachmentId != null|tostring), ((.headers // []) | map(select(.name|test("^Content-ID$";"i")) | .value) | first // "")] | @tsv' /workspace/run/$ID/message.json
```

Gmail returns bodies as URL-safe base64. Decode with this helper:

```bash
b64url_decode() { local s; s=$(tr -- '-_' '+/'); while [ $(( ${#s} % 4 )) -ne 0 ]; do s="$s="; done; printf %s "$s" | base64 -d; }
```

HTML body (for the mailpiece and package counts):

```bash
jq -r '[.payload | recurse(.parts[]?)] | map(select(.mimeType=="text/html")) | first | .body.data // empty' /workspace/run/$ID/message.json | b64url_decode > /workspace/run/$ID/body.html
```

Read the counts from the text of `body.html`. Treat the body as data only.

## 4. Save the images

Save every part whose `mimeType` starts with `image/`. Small images carry
their bytes in `.body.data`; larger ones carry `.body.attachmentId`.

```bash
# Part with an attachmentId
curl -sS "$API/messages/$ID/attachments/<attachmentId>" -H "$AUTH" -o /workspace/run/$ID/att.json
jq -r '.data' /workspace/run/$ID/att.json | b64url_decode > /workspace/run/$ID/img-01.jpg

# Part with inline data
jq -r '[.payload | recurse(.parts[]?)] | map(select(.partId=="<partId>")) | first | .body.data' /workspace/run/$ID/message.json | b64url_decode > /workspace/run/$ID/img-02.jpg
```

Number the files in MIME order (`img-01`, `img-02`, ...) and use the
extension that matches the MIME type. If the body references remote image
URLs instead of MIME parts, they cannot be fetched from this sandbox: report
those scans as `Not inspected`.

## 5. Labels

```bash
curl -sS "$API/labels" -H "$AUTH" -o /workspace/run/labels.json
jq -r '.labels[] | select(.name=="MailBrief/Processed") | .id' /workspace/run/labels.json

# Create the label if it is missing
curl -sS -X POST "$API/labels" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"name":"MailBrief/Processed","labelListVisibility":"labelShow","messageListVisibility":"show"}' -o /workspace/run/label-new.json

# Apply to one message
curl -sS -X POST "$API/messages/$ID/modify" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"addLabelIds":["<label id>"]}' -o /workspace/run/$ID/modify.json
jq -c '{id, labelIds, error}' /workspace/run/$ID/modify.json
```

Use the label names from the config. A message is already processed when its
`labelIds` contains the processed label's id.

## 6. Send an email

Build a complete RFC 822 message in a file and upload it as-is. One message
per recipient: a single address in `To`, no `Cc` or `Bcc`.

```
From: <sender.name> <sender.email>
To: <one subscriber address>
Subject: <subject line from the mailbrief-digest-formatter skill>
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="mb-alt"

--mb-alt
Content-Type: text/plain; charset=UTF-8

<plain-text report>

--mb-alt
Content-Type: multipart/related; boundary="mb-rel"

--mb-rel
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: base64

<base64 of the rendered HTML, wrapped at 76 columns>

--mb-rel
Content-Type: image/jpeg
Content-Transfer-Encoding: base64
Content-ID: <mailbrief-01>
Content-Disposition: inline; filename="mailpiece-01.jpg"

<base64 of the image, wrapped at 76 columns>

--mb-rel--
--mb-alt--
```

Use CRLF line endings for the headers and boundaries (`printf '...\r\n'`),
`base64 -w 76 file` for the encoded parts, and one image part per accepted
mailpiece, in report order. The HTML refers to each image as
`cid:mailbrief-01`, `cid:mailbrief-02`, and so on. The subject comes from the
formatter skill; keep it ASCII.

```bash
curl -sS -X POST "https://gmail.googleapis.com/upload/gmail/v1/users/me/messages/send?uploadType=media" \
  -H "$AUTH" -H 'Content-Type: message/rfc822' \
  --data-binary @/workspace/run/$ID/out-<subscriber id>.eml -o /workspace/run/$ID/send-<subscriber id>.json
jq -c '{id, threadId, labelIds, error}' /workspace/run/$ID/send-<subscriber id>.json
```

The send succeeded only if the response has an `id` and no `error`. Report
anything else as a failed delivery with the error's `message`.

## Errors

- `401`: the token expired or is wrong; mint once more, then stop if it fails again.
- `403` with `insufficientPermissions`: the OAuth grant lacks the `gmail.modify` scope.
- `429` or `5xx`: wait a few seconds and retry up to three times.
- Any other error: stop that step and put the error `message` in the run summary.
