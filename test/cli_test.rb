# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "test_helper"
require "stringio"

class CLITest < Minitest::Test
  def digest_payload(subject: "Hello")
    {
      "schema_version" => "prism-mail.digest.v1",
      "mode" => "extractive",
      "mailbox_id" => "box",
      "window" => { "since" => "2026-09-13T00:00:00Z", "before" => "2026-09-14T00:00:00Z" },
      "matched_count" => 1,
      "selected_count" => 1,
      "omitted_count" => 0,
      "entries" => [
        {
          "kind" => "source_excerpt",
          "evidence" => {
            "id" => "m1", "mailbox_id" => "box", "sender" => "a@example.test",
            "subject" => subject, "received_at" => "2026-09-13T04:00:00Z"
          }
        }
      ]
    }
  end

  def request(artifact_kind: "mail.digest", payload: digest_payload, **overrides)
    {
      "schema_version" => "prism-porter.request.v1",
      "artifact" => { "artifact_kind" => artifact_kind, "artifact_id" => "artifact-1", "payload" => payload },
      "routes" => [
        {
          "artifact_kind" => artifact_kind,
          "logical_context" => { "workspace" => "NEW_OCEAN", "channel" => "MAIL" }
        }
      ]
    }.merge(overrides.transform_keys(&:to_s))
  end

  def run_cli(body)
    output = StringIO.new
    errors = StringIO.new
    status = PrismPorter::CLI.run(input: StringIO.new(body), output: output, errors: errors)
    [status, output.string, errors.string]
  end

  def test_worker_returns_versioned_transport_neutral_delivery_intent
    status, output, errors = run_cli(JSON.generate(request))
    payload = JSON.parse(output)

    assert_equal 0, status
    assert_empty errors
    assert_equal "prism-porter.delivery-intent.v1", payload.fetch("schema_version")
    assert_equal "NEW_OCEAN", payload.dig("logical_context", "workspace")
    assert_equal "MAIL", payload.dig("logical_context", "channel")
    assert_equal "plain_text", payload.dig("presentation", "format")
    assert_match(/\A[0-9a-f]{64}\z/, payload.fetch("idempotency_key"))
    refute_includes output, "chat_id"
    refute_includes output, "message_thread_id"
  end

  def test_worker_chunking_is_lossless_and_positioned
    source = request(payload: digest_payload(subject: "x" * 300), chunk_max_chars: 64)
    status, output, = run_cli(JSON.generate(source))
    payload = JSON.parse(output)
    chunks = payload.fetch("chunks")

    assert_equal 0, status
    assert_operator chunks.length, :>, 1
    assert_equal((1..chunks.length).to_a, chunks.map { |chunk| chunk.fetch("position") })
    assert(chunks.all? { |chunk| chunk.fetch("total") == chunks.length && chunk.fetch("text").length <= 64 })
  end

  def test_worker_fails_closed_for_invalid_contracts
    status, output, errors = run_cli("not-json")
    assert_equal 1, status
    assert_empty output
    assert_equal "invalid_json", JSON.parse(errors).fetch("error")

    invalid = request
    invalid["schema_version"] = "unknown"
    status, output, errors = run_cli(JSON.generate(invalid))
    assert_equal 1, status
    assert_empty output
    assert_equal "InvalidInput", JSON.parse(errors).fetch("error")

    missing_route = request
    missing_route["routes"] = [{ "artifact_kind" => "mail.invitation",
                                 "logical_context" => { "workspace" => "NEW_OCEAN", "channel" => "MAIL" } }]
    status, output, errors = run_cli(JSON.generate(missing_route))
    assert_equal 1, status
    assert_empty output
    assert_equal "RouteNotFound", JSON.parse(errors).fetch("error")
  end

  def test_worker_enforces_input_byte_limit
    status, output, errors = run_cli("x" * (PrismPorter::CLI::MAX_INPUT_BYTES + 1))

    assert_equal 1, status
    assert_empty output
    assert_equal "InvalidInput", JSON.parse(errors).fetch("error")
  end
end
