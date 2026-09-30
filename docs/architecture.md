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
- `signal.alert` accepts `prism-hub.signal-alert.v1` and renders it in Ukrainian (see below).

## `signal.alert`

An alert, or the retraction of one, about a report from an unofficial source. The payload is checked field by field; a value the renderer does not know (an event, hazard class, kind, likelihood, a link that is not a `https://t.me/` address, a control character in a place name) fails with `InvalidArtifact` instead of being printed.

| Field | Meaning |
| --- | --- |
| `event` | `alert` or `retraction` |
| `hazard` | `class` (`drone`, `bomb`, `missile`) and `kinds` (`air.*`) |
| `place.name` | display name, or `null` |
| `proximity` | `target`, or `nearby` (passing or near the place) |
| `likelihood` | `moderate`, `high`, or `null`; omitted from the text when `null` |
| `sources` | up to three reports: `source_id`, `url`, `observed_at` |
| `event_at`, `event_url` | when the source made the statement this message is about, and its link |
| `still_active` | for a retraction, other reports of the same class that still cover the person |

Rules the text keeps:

- The source is named and called unofficial, and the message says it is not an air-raid alert.
- Times are shown in Ukraine's local time, computed from the UTC instant with the EU daylight-saving rule, so a rendering does not depend on the machine.
- An alert never says a threat has ended, and the artifact's `valid_until` is not shown: an expiry is not an all-clear.
- A retraction says the source wrote that the threat was called off, that this is not an official all-clear, lists other reports that still apply, and repeats that no message does not mean safety.
- The person's position is not in the artifact and never in the text.

AI is not required for routing, rendering, or correctness.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
