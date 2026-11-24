# Transient voice presentation

Porter converts a caller-selected PCM16 WAV artifact into a bounded native voice
presentation, selected by the explicit profile `voice.ogg-opus.v1`. The
profile produces mono Ogg/Opus, 48 kHz, nominal 32 kbit/s. Hub owns the choice
of profile, authorization, routing and cancellation. Transport adapters own
provider APIs and coordinates. The encoder has no Telegram dependency.

The API is in-process only. It is not a serializable DeliveryIntent, normal
text chunk, CLI command, durable outbox entry, or publication. Hand bytes
directly to the authorized transport. JSON and Marshal serialization are
refused; inspect is redacted. These safeguards do not prevent a caller from
intentionally reading or copying bytes. Never log or persist private audio.

Input is strict PCM16 RIFF/WAVE (fmt and data chunks only), mono/stereo,
8–48 kHz, up to 300 seconds and 60 MiB. Output is limited to 10 MiB; the
external ffmpeg executable is bounded by a wall timeout and file size limit.
No silent truncation, metadata copying, shell interpolation or fallback.
Temporary files are removed on normal success/failure. Deploy on a restricted
Linux worker with private tmpfs, CPU/memory quotas and verified ffmpeg/libopus;
process death is not a guarantee of immediate cleanup on persistent storage.
The caller must enforce concurrency and discard results after cancellation.

The existing text Presentation, DeliveryIntent schema, CLI and mail/signal
renderers are unchanged. The integration with Hub and the bot is separate.
No deployment is implied.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
