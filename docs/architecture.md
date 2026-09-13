# Prism Porter architecture

Prism Porter is the transport-neutral egress capability in the Prism ecosystem. It converts a Hub-selected artifact plus route policy into a deterministic presentation and a context-bound delivery intent. It is not the Prism orchestrator, not a transport client, not a mail source, and not an AI runtime.

The dependency direction is:

```text
Prism Hub
   │
   ├── artifact envelope
   └── route policy
          │
          ▼
     Prism Porter
       ├── renderer
       ├── logical context
       └── lossless chunking
          │
          ▼
    DeliveryIntent
          │
          ▼
 transport adapter owned elsewhere
```

## Ownership

Porter owns artifact-to-route resolution, deterministic presentation, delivery-intent construction, and transport-neutral chunking.

Porter does not own workflow orchestration, schedules, source ingestion, user identity, delivery checkpoints, transport credentials, retries against concrete providers, or Telegram chat/thread coordinates.

`LogicalContext` names a Prism-owned destination such as a workspace and channel. A transport binding such as Telegram `chat_id` / `message_thread_id` is resolved outside Porter.

## Determinism and provenance

The same artifact, route policy, renderer version, and chunk size produce the same presentation, ordered chunks, and idempotency key. Renderers may display only factual fields present in their input artifact; they must not invent missing values.

Chunking is lossless. Concatenating chunk text in `position` order reconstructs the exact presentation text. Chunk position and total count are metadata, not transport-specific markup.

## Initial renderers

- `mail.digest` accepts `prism-mail.digest.v1` and the current Hub aggregate `prism-hub.mail-digests.v1`.
- `mail.invitation` accepts `prism-mail.invitation.v1` and omits optional fields that are absent from the artifact.

AI is not required for routing, rendering, or correctness.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
