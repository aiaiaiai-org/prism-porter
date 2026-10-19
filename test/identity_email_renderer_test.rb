# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "test_helper"
require "json"
require "stringio"

class IdentityEmailRendererTest < Minitest::Test
  CLIENTS = {
    "prism" => { "from" => "prism@aiaiaiai.org", "brand" => "aiaiaiai × Prism" },
    "nilx-one" => { "from" => "n-reply@nilx.one", "brand" => "aiaiaiai × 0x1" }
  }.freeze
  CODE = "083641".freeze

  def renderer
    PrismPorter::Rendering::IdentityEmailRenderer.new(clients: CLIENTS)
  end

  def render(**overrides)
    params = { schema_version: "identity.email-challenge.v1", client_id: "prism",
               intent: "verify_email", locale: "uk", code: CODE }.merge(overrides)
    renderer.render(**params)
  end

  def test_verified_client_configuration_chooses_sender_and_brand
    mail = render
    assert_equal "prism@aiaiaiai.org", mail.from
    assert_equal "aiaiaiai × Prism — Підтвердження електронної адреси", mail.subject
    assert_includes mail.body, "Підтвердіть електронну адресу цим кодом:"
    assert_includes mail.body, CODE

    other = render(client_id: "nilx-one", intent: "recover", locale: "en")
    assert_equal "n-reply@nilx.one", other.from
    assert_includes other.subject, "aiaiaiai × 0x1"
    assert_includes other.body, "continue account recovery"
    refute_includes other.body, "Prism"
  end

  def test_each_intent_has_deterministic_ukrainian_and_english_copy
    %w[uk en].each do |locale|
      PrismPorter::Rendering::IdentityEmailRenderer::INTENTS.each do |intent|
        first = render(locale: locale, intent: intent)
        second = render(locale: locale, intent: intent)
        assert_equal first.subject, second.subject
        assert_equal first.body, second.body
        assert_includes first.body, CODE
      end
    end
  end

  def test_unknown_schema_client_intent_locale_and_invalid_codes_fail_closed
    cases = [
      { client_id: "other" }, { client_id: nil }, { intent: "reset_without_proof" },
      { locale: "ru" }, { schema_version: "identity.email-challenge.v2" },
      { code: "12\nBcc:bad@example.test" }, { code: "1234" }, { code: "123456789" }, { code: nil }
    ]
    cases.each do |override|
      assert_raises(PrismPorter::InvalidArtifact, override.inspect) { render(**override) }
    end
  end

  def test_sender_configuration_rejects_header_injection
    bad = [
      { "prism" => { "from" => "a@example.test\r\nBcc:bad@example.test", "brand" => "Good" } },
      { "prism" => { "from" => "a@example.test", "brand" => "Bad\nBcc:bad@example.test" } },
      { "prism" => { "from" => "a@example.test", "brand" => "Bad\u2028Line" } },
      { "bad id" => { "from" => "a@example.test", "brand" => "Good" } },
      { "prism" => { "from" => "a@localhost", "brand" => "Good" } }
    ]
    bad.each do |clients|
      assert_raises(PrismPorter::InvalidInput, clients.inspect) do
        PrismPorter::Rendering::IdentityEmailRenderer.new(clients: clients)
      end
    end
  end

  def test_malformed_utf8_and_incompatible_encodings_fail_closed
    malformed = "\xC3\x28".b.force_encoding(Encoding::UTF_8)
    error = assert_raises(PrismPorter::InvalidArtifact) { render(code: malformed) }
    assert_equal "invalid identity mail code", error.message
    error = assert_raises(PrismPorter::InvalidArtifact) { render(client_id: malformed) }
    assert_equal "unknown identity mail client", error.message

    settings = CLIENTS.fetch("prism")
    error = assert_raises(PrismPorter::InvalidInput) do
      PrismPorter::Rendering::IdentityEmailRenderer.new(clients: { malformed => settings })
    end
    assert_equal "invalid email client ID", error.message

    error = assert_raises(PrismPorter::InvalidInput) do
      PrismPorter::Rendering::IdentityEmailRenderer.new(
        clients: { "prism" => settings.merge("from" => malformed) }
      )
    end
    assert_equal "invalid configured email sender", error.message

    error = assert_raises(PrismPorter::InvalidInput) do
      PrismPorter::Rendering::IdentityEmailRenderer.new(
        clients: { "prism" => settings.merge("brand" => malformed) }
      )
    end
    assert_equal "invalid configured email branding", error.message

    assert_raises(PrismPorter::InvalidArtifact) do
      render(code: "123456".encode(Encoding::UTF_16LE))
    end
    assert_raises(PrismPorter::InvalidInput) do
      PrismPorter::Rendering::IdentityEmailRenderer.new(
        clients: { "prism" => settings.merge("from" => "a@example.test".encode(Encoding::UTF_16LE)) }
      )
    end
  end

  def test_message_inspect_and_errors_do_not_expose_code
    mail = render
    refute_includes mail.inspect, CODE
    assert_raises(FrozenError) { mail.body << "extra" }
    assert_raises(FrozenError) { mail.subject << "extra" }
    assert_raises(FrozenError) { mail.from << "extra" }
    error = assert_raises(PrismPorter::InvalidArtifact) do
      render(schema_version: "bad")
    end
    refute_includes error.message, CODE
  end

  def test_identity_secrets_are_excluded_from_serializable_worker
    refute PrismPorter::CLI::RENDERERS.key?("identity.email-challenge")
    request = {
      "schema_version" => "prism-porter.request.v1",
      "artifact" => {
        "artifact_kind" => "identity.email-challenge", "artifact_id" => "secret-1",
        "payload" => { "schema_version" => "identity.email-challenge.v1", "code" => CODE }
      },
      "routes" => [
        { "artifact_kind" => "identity.email-challenge",
          "logical_context" => { "workspace" => "identity", "channel" => "email" } }
      ]
    }
    output = StringIO.new
    errors = StringIO.new
    result = PrismPorter::CLI.run(input: StringIO.new(JSON.generate(request)), output: output, errors: errors)
    assert_equal 1, result
    assert_empty output.string
    refute_includes errors.string, CODE
    assert_equal "RendererNotFound", JSON.parse(errors.string).fetch("error")
  end
end
