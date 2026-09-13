# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "json"

module PrismPorter
  class CLI
    MAX_INPUT_BYTES = 2 * 1024 * 1024
    REQUEST_SCHEMA = "prism-porter.request.v1".freeze
    RENDERERS = {
      "mail.digest" => Rendering::MailDigestRenderer.new,
      "mail.invitation" => Rendering::MailInvitationRenderer.new
    }.freeze

    def self.run(input: $stdin, output: $stdout, errors: $stderr)
      intent = build(parse_request(input))
      output.puts(JSON.generate(intent.to_h))
      0
    rescue JSON::ParserError
      errors.puts(JSON.generate(error: "invalid_json"))
      1
    rescue KeyError
      errors.puts(JSON.generate(error: "invalid_request"))
      1
    rescue Error => e
      errors.puts(JSON.generate(error: e.class.name.split("::").last))
      1
    end

    def self.parse_request(input)
      raw = input.read(MAX_INPUT_BYTES + 1)
      raise InvalidInput, "worker request exceeds byte limit" if raw.bytesize > MAX_INPUT_BYTES

      value = JSON.parse(raw)
      raise InvalidInput, "worker request must be an object" unless value.is_a?(Hash)

      value
    end
    private_class_method :parse_request

    def self.build(request)
      raise InvalidInput, "unsupported worker request schema" unless request.fetch("schema_version") == REQUEST_SCHEMA

      envelope = build_envelope(request.fetch("artifact"))
      policy = Routing::RoutePolicy.new(routes: build_routes(request.fetch("routes")))
      chunker = Presentation::Chunker.new(max_chars: request.fetch("chunk_max_chars", Presentation::Chunker::DEFAULT_MAX_CHARS))
      Application::BuildDeliveryIntent.new(route_policy: policy, renderers: RENDERERS, chunker: chunker).call(
        envelope: envelope
      )
    end
    private_class_method :build

    def self.build_envelope(value)
      object = require_object(value)
      Domain::ArtifactEnvelope.new(
        artifact_kind: object.fetch("artifact_kind"),
        artifact_id: object.fetch("artifact_id"),
        payload: object.fetch("payload")
      )
    end
    private_class_method :build_envelope

    def self.build_routes(value)
      raise InvalidInput, "routes must be a nonempty array" unless value.is_a?(Array) && !value.empty?

      value.each_with_object({}) do |entry, routes|
        route = require_object(entry)
        kind = route.fetch("artifact_kind")
        raise InvalidInput, "duplicate route for artifact kind" if routes.key?(kind)

        context = require_object(route.fetch("logical_context"))
        routes[kind] = Domain::LogicalContext.new(
          workspace: context.fetch("workspace"), channel: context.fetch("channel")
        )
      end
    end
    private_class_method :build_routes

    def self.require_object(value)
      raise InvalidInput, "worker request object is invalid" unless value.is_a?(Hash)

      value
    end
    private_class_method :require_object
  end
end
