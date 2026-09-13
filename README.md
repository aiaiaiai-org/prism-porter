# prism-porter

Provider-neutral Prism artifact routing and presentation.

Prism Porter turns a versioned artifact into a deterministic, context-bound `DeliveryIntent`. It deliberately stops before concrete transport delivery: Prism Hub owns orchestration and logical-context bindings, while transport adapters such as Prism Bot own provider APIs and credentials.

Current bootstrap supports:

- immutable `ArtifactEnvelope` and `LogicalContext` values;
- exact `RoutePolicy` resolution;
- deterministic `mail.digest` rendering for `prism-mail.digest.v1` and `prism-hub.mail-digests.v1`;
- deterministic `mail.invitation` rendering for `prism-mail.invitation.v1`;
- lossless transport-neutral chunking with position metadata;
- stable delivery idempotency keys;
- typed fail-closed errors.

See [`docs/architecture.md`](docs/architecture.md) for the ownership boundary.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
