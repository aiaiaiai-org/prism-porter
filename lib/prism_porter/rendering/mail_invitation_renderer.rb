# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Rendering
    class MailInvitationRenderer
      SCHEMA = "prism-mail.invitation.v1".freeze
      OPTIONAL_LINES = {
        "platform" => "Platform",
        "opportunity_title" => "Opportunity",
        "compensation" => "Compensation",
        "engagement_type" => "Engagement",
        "duration" => "Duration",
        "source_url" => "Source URL"
      }.freeze

      def render(envelope)
        payload = envelope.payload
        require_schema(payload, SCHEMA)
        lines = base_lines(payload)
        append_optional_lines(lines, payload)
        Domain::Presentation.new(text: lines.join("\n"))
      end

      private

      def base_lines(payload)
        [
          "Mail invitation",
          "From: #{text(payload, 'sender')}",
          "Subject: #{text(payload, 'subject')}",
          "Received: #{text(payload, 'received_at')}",
          "Source message: #{text(payload, 'source_message_reference')}"
        ]
      end

      def append_optional_lines(lines, payload)
        OPTIONAL_LINES.each do |field, label|
          value = payload[field]
          lines << "#{label}: #{value}" if value.is_a?(String) && !value.empty?
        end
      end

      def require_schema(payload, expected)
        raise InvalidArtifact, "unsupported invitation schema" unless payload["schema_version"] == expected
      end

      def text(payload, key)
        value = payload[key]
        raise InvalidArtifact, "invitation is missing #{key}" unless value.is_a?(String) && !value.empty?

        value
      end
    end
  end
end
