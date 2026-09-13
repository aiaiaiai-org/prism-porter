# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "test_helper"

class PorterTest < Minitest::Test
  def context
    PrismPorter::Domain::LogicalContext.new(workspace: "NEW_OCEAN", channel: "MAIL")
  end

  def digest_payload(entries: nil)
    entries ||= [
      {
        "kind" => "source_excerpt",
        "evidence" => {
          "id" => "m1", "mailbox_id" => "box", "sender" => "Alice <alice@example.test>",
          "subject" => "Hello", "excerpt" => "Body", "received_at" => "2026-09-13T04:00:00Z"
        }
      }
    ]
    {
      "schema_version" => "prism-mail.digest.v1",
      "mode" => "extractive",
      "mailbox_id" => "box",
      "window" => { "since" => "2026-09-13T00:00:00Z", "before" => "2026-09-14T00:00:00Z" },
      "matched_count" => entries.length,
      "selected_count" => entries.length,
      "omitted_count" => 0,
      "entries" => entries
    }
  end

  def invitation_payload
    {
      "schema_version" => "prism-mail.invitation.v1",
      "evidence_id" => "m2",
      "mailbox_id" => "box",
      "received_at" => "2026-09-13T04:30:00Z",
      "sender" => "Upwork <donotreply@upwork.com>",
      "subject" => "Invitation to interview: Swift Engineer",
      "source_message_reference" => "m2",
      "platform" => "upwork",
      "opportunity_title" => "Swift Engineer",
      "provenance" => {}
    }
  end

  def build(envelope, max_chars: 3500)
    routes = { "mail.digest" => context, "mail.invitation" => context }
    renderers = {
      "mail.digest" => PrismPorter::Rendering::MailDigestRenderer.new,
      "mail.invitation" => PrismPorter::Rendering::MailInvitationRenderer.new
    }
    PrismPorter::Application::BuildDeliveryIntent.new(
      route_policy: PrismPorter::Routing::RoutePolicy.new(routes: routes),
      renderers: renderers,
      chunker: PrismPorter::Presentation::Chunker.new(max_chars: max_chars)
    ).call(envelope: envelope)
  end

  def test_same_artifact_and_policy_are_deterministic
    envelope = PrismPorter::Domain::ArtifactEnvelope.new(
      artifact_kind: "mail.digest", artifact_id: "digest-1", payload: digest_payload
    )

    first = build(envelope).to_h
    second = build(envelope).to_h

    assert_equal first, second
    assert_equal "NEW_OCEAN", first[:logical_context][:workspace]
    assert_equal "MAIL", first[:logical_context][:channel]
    assert_match(/\A[0-9a-f]{64}\z/, first[:idempotency_key])
  end

  def test_chunking_is_complete_ordered_and_lossless
    entries = 20.times.map do |index|
      {
        "kind" => "source_excerpt",
        "evidence" => {
          "id" => "m#{index}", "mailbox_id" => "box", "sender" => "sender#{index}@example.test",
          "subject" => "Subject #{index} " + ("x" * 40), "excerpt" => "", "received_at" => "2026-09-13T04:00:00Z"
        }
      }
    end
    envelope = PrismPorter::Domain::ArtifactEnvelope.new(
      artifact_kind: "mail.digest", artifact_id: "digest-long", payload: digest_payload(entries: entries)
    )

    intent = build(envelope, max_chars: 96)

    assert_operator intent.chunks.length, :>, 1
    assert_equal intent.presentation.text, intent.chunks.map(&:text).join
    assert_equal((1..intent.chunks.length).to_a, intent.chunks.map(&:position))
    assert(intent.chunks.all? { |chunk| chunk.total == intent.chunks.length && chunk.text.length <= 96 })
  end

  def test_invitation_renderer_does_not_fabricate_optional_fields
    envelope = PrismPorter::Domain::ArtifactEnvelope.new(
      artifact_kind: "mail.invitation", artifact_id: "invite-1", payload: invitation_payload
    )
    text = build(envelope).presentation.text

    assert_includes text, "Platform: upwork"
    assert_includes text, "Opportunity: Swift Engineer"
    refute_includes text, "Compensation:"
    refute_includes text, "Duration:"
    refute_includes text, "Source URL:"
  end

  def test_aggregate_hub_digest_is_supported
    payload = {
      "schema_version" => "prism-hub.mail-digests.v1",
      "mode" => "extractive",
      "window" => { "since" => "2026-09-13T00:00:00Z", "before" => "2026-09-14T00:00:00Z" },
      "mailbox_count" => 1,
      "matched_count" => 1,
      "selected_count" => 1,
      "omitted_count" => 0,
      "entries" => [
        {
          "mailbox" => { "id" => "box", "address" => "me@example.test" },
          "kind" => "source_excerpt",
          "evidence" => {
            "id" => "m1", "sender" => "a@example.test", "subject" => "Hi",
            "received_at" => "2026-09-13T04:00:00Z"
          }
        }
      ]
    }
    envelope = PrismPorter::Domain::ArtifactEnvelope.new(
      artifact_kind: "mail.digest", artifact_id: "aggregate-1", payload: payload
    )

    text = build(envelope).presentation.text

    assert_includes text, "Mailboxes: 1"
    assert_includes text, "me@example.test"
  end

  def test_route_and_renderer_fail_closed
    envelope = PrismPorter::Domain::ArtifactEnvelope.new(
      artifact_kind: "mail.digest", artifact_id: "digest-1", payload: digest_payload
    )
    assert_raises(PrismPorter::RouteNotFound) do
      PrismPorter::Routing::RoutePolicy.new(routes: { "other" => context }).resolve(envelope)
    end

    use_case = PrismPorter::Application::BuildDeliveryIntent.new(
      route_policy: PrismPorter::Routing::RoutePolicy.new(routes: { "mail.digest" => context }),
      renderers: {}
    )
    assert_raises(PrismPorter::RendererNotFound) { use_case.call(envelope: envelope) }
  end
end
