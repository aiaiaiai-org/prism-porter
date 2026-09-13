# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Rendering
    class MailDigestRenderer
      SINGLE_SCHEMA = "prism-mail.digest.v1".freeze
      AGGREGATE_SCHEMA = "prism-hub.mail-digests.v1".freeze

      def render(envelope)
        payload = envelope.payload
        case payload["schema_version"]
        when SINGLE_SCHEMA then render_single(payload)
        when AGGREGATE_SCHEMA then render_aggregate(payload)
        else raise InvalidArtifact, "unsupported mail digest schema"
        end
      end

      private

      def render_single(payload)
        entries = array(payload, "entries")
        validate_count(payload, entries)
        lines = header(window(payload), 1, integer(payload, "matched_count"))
        append_single_entries(lines, entries, payload.fetch("mailbox_id"))
        Domain::Presentation.new(text: lines.join("\n"))
      rescue KeyError
        raise InvalidArtifact, "single-mailbox digest is incomplete", cause: nil
      end

      def append_single_entries(lines, entries, mailbox_id)
        entries.each_with_index do |entry, index|
          evidence = hash(hash(entry, "evidence"), nil)
          lines.concat(entry_lines(index + 1, evidence, mailbox_id))
        end
      end

      def render_aggregate(payload)
        window = window(payload)
        entries = array(payload, "entries")
        validate_count(payload, entries)
        lines = header(window, integer(payload, "mailbox_count"), integer(payload, "matched_count"))
        entries.each_with_index do |entry, index|
          mailbox = hash(entry, "mailbox")
          evidence = hash(entry, "evidence")
          lines.concat(entry_lines(index + 1, evidence, mailbox_label(mailbox)))
        end
        Domain::Presentation.new(text: lines.join("\n"))
      end

      def header(window, mailbox_count, message_count)
        [
          "Mail digest",
          "Period: #{window.fetch('since')} — #{window.fetch('before')}",
          "Mailboxes: #{mailbox_count}",
          "Messages: #{message_count}",
          ""
        ]
      end

      def entry_lines(position, evidence, source_account)
        [
          "#{position}. #{text(evidence, 'sender')} — #{text(evidence, 'subject', allow_empty: true)}",
          "   #{text(evidence, 'received_at')} · #{source_account}"
        ]
      end

      def mailbox_label(mailbox)
        %w[address email name id].each do |key|
          value = mailbox[key]
          return value if value.is_a?(String) && !value.empty?
        end
        raise InvalidArtifact, "digest mailbox has no source account identity"
      end

      def window(payload)
        value = hash(payload, "window")
        { "since" => text(value, "since"), "before" => text(value, "before") }
      end

      def validate_count(payload, entries)
        selected = integer(payload, "selected_count")
        raise InvalidArtifact, "digest selected_count does not match entries" unless selected == entries.length
      end

      def integer(payload, key)
        value = payload[key]
        raise InvalidArtifact, "digest #{key} must be a nonnegative integer" unless value.is_a?(Integer) && value >= 0

        value
      end

      def array(payload, key)
        value = payload[key]
        raise InvalidArtifact, "digest #{key} must be an array" unless value.is_a?(Array)

        value
      end

      def hash(payload, key)
        value = key.nil? ? payload : payload[key]
        raise InvalidArtifact, "digest object is missing" unless value.is_a?(Hash)

        value
      end

      def text(payload, key, allow_empty: false)
        value = payload[key]
        valid = value.is_a?(String) && (allow_empty || !value.empty?)
        raise InvalidArtifact, "digest #{key} must be text" unless valid

        value
      end
    end
  end
end
