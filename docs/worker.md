# Prism Porter worker boundary

The `prism-porter` executable is a one-shot JSON worker for Prism Hub. It keeps Hub and Porter independently deployable while preserving the same domain contracts as the Ruby library.

Input is `prism-porter.request.v1` on standard input:

```json
{
  "schema_version": "prism-porter.request.v1",
  "artifact": {
    "artifact_kind": "mail.digest",
    "artifact_id": "digest:example",
    "payload": {}
  },
  "routes": [
    {
      "artifact_kind": "mail.digest",
      "logical_context": {
        "workspace": "NEW_OCEAN",
        "channel": "MAIL"
      }
    }
  ],
  "chunk_max_chars": 3500
}
```

The worker writes exactly one `prism-porter.delivery-intent.v1` JSON object on success. The delivery intent contains the logical context, transport-neutral presentation metadata, complete ordered chunks, and a stable idempotency key.

The request never contains Telegram `chat_id`, `message_thread_id`, bot tokens, or other transport credentials. Hub resolves logical context to a concrete client binding only after Porter has produced the delivery intent.

Input is bounded to 2 MiB. Malformed JSON, unsupported schemas, duplicate routes, missing routes, unsupported artifact kinds, and invalid artifacts fail explicitly and do not produce a partial delivery intent.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
