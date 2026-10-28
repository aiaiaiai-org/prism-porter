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
- `signal.board` and `signal.status` accept `prism-hub.signal-board.v1` and `prism-hub.signal-status.v1`: one person's live board of an attack and the status line above it (see below).

## Transactional identity email (ephemeral API)

The `PrismPorter::Rendering::IdentityEmailRenderer` is a separate, **in-process** presentation API for `identity.email-challenge.v1` (intent: `verify_email`, `sign_in`, `link_email`, or `recover`; locales `uk`/`en`). This is **not** a normal `DeliveryIntent`. The CLI and its routing registry must not accept OTP-bearing identity artifacts, because they serialize presentation text and can persist or log one-time secrets.

The renderer receives a **server-verified** `client_id` and an Identity-issued 6–8-digit code. Its constructor requires an explicit allowlist of clients, each with a configured `from` and product `brand`. It rejects unknown clients, schema versions, intents, locales, malformed codes, and unsafe mail headers. Example **unprovisioned** sender options are `prism@aiaiaiai.org` and `n-reply@nilx.one`; these examples do not establish the right to transmit email from those domains.

The returned immutable message contains `from`, `subject`, and plain-text `body`. It must be handed **immediately** to an Identity-owned transactional email transport; do not serialize, enqueue, cache, log, or put it into Hub's delivery artifacts. `inspect` is redacted to reduce accidental logging, but it does **not** prevent intentional reads of `body`. A secure transient delivery path remains a required integration before this renderer can support production authentication.

Porter does **not** generate, store, expire, validate, or consume challenges, select the recipient mailbox, verify sender-domain DNS (SPF/DKIM/DMARC), authorize SMTP/API credentials, perform delivery/retry policy, or issue user sessions. Those are responsibilities of Identity and its email adapter. Avoid introducing a dependency on Prism Hub for a critical login path.

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

- The recipient does not see source names, IDs, channels, or original post links. The validated
  artifact retains provenance internally.
- No message repeats that the service is unofficial: the bot says so once, when the person starts.
- The event update time is shown in Ukraine's local time, computed from its UTC instant with the EU daylight-saving rule, independently of the machine clock.
- An alert never says a threat has ended, and the artifact's `valid_until` is not shown: an expiry is not an all-clear.
- A retraction says a prior report was withdrawn, without attributing it to a named provider, and
  lists other reports that still apply. It never says the threat is over or the place is safe.
- The person's position is not in the artifact and never in the text.

## `signal.board` and `signal.status`

During an attack a person keeps two messages instead of one per report. The hub decides what they hold and when the status rings; Porter only writes the words. Both are checked like `signal.alert`: an unknown kind, level, count, source, or a control character in a name fails with `InvalidArtifact`.

`signal.board` lists the objects the sources reported for the person, built by the hub from Prism Signal tracks:

| Field | Meaning |
| --- | --- |
| `since`, `as_of` | the attack's first report, and when the board was built |
| `entries` | `level` (`here`: the person's zone; `region`: their oblast), `kind` (`air.*`), `count` (objects, or `null` when no source said how many), `place`, `target`, `last_seen_at`, `source` (`@channel`, checked and kept for audit, never shown), `quiet` (live but no news) |
| `quiet` | objects with no news for a long time: shown apart, never as ended |
| `ended` | how many objects were shot down or called off |

With no entries and nothing quiet, the board says the reports ended and how many; it never says a place is safe.

`signal.status` is `level` `here`, `region`, or `quiet`, with the hazards at each level. A quiet status says the sources went quiet, never that a place is safe, and, when the hub passes `position_at`, reminds the person to refresh an old position (`в суботу о 12:34`).

AI is not required for routing, rendering, or correctness.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
