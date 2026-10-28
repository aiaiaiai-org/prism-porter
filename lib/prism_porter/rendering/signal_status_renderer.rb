# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Rendering
    # Renders one person's status line: how close the danger is, and what.
    #
    # The hub decides when it rings; this only says it. A quiet status says the sources went
    # quiet, and it is the one place a stale position is mentioned. Nothing here says a place is
    # safe; what the service is, the person is told once when they start.
    class SignalStatusRenderer
      SCHEMA = "prism-hub.signal-status.v1".freeze
      LEVELS = %w[here region quiet].freeze
      QUIET = "⚪ Джерела затихли\nНових повідомлень для вашої зони немає.".freeze
      HEADLINES = { "here" => "🔴 Загроза у вашій зоні", "region" => "🟠 Загроза у вашій області" }.freeze

      def render(envelope)
        payload = envelope.payload
        raise InvalidArtifact, "unsupported signal status schema" unless payload["schema_version"] == SCHEMA

        level = payload["level"]
        raise InvalidArtifact, "signal status level is unknown" unless LEVELS.include?(level)

        text = level == "quiet" ? quiet(payload) : danger(payload, level)
        Domain::Presentation.new(text: text)
      end

      private

      def danger(payload, level)
        here = SignalBoardReading.list(payload, "here")
        region = SignalBoardReading.list(payload, "region")
        main = level == "here" ? here : region
        raise InvalidArtifact, "signal status names no hazard for its level" if main.empty?

        lines = [HEADLINES.fetch(level), "", *main.map { |item| SignalBoardReading.hazard(item) }]
        lines << "🟠 на вашу область: #{hazards(region)}" if level == "here" && !region.empty?
        lines.join("\n")
      end

      def hazards(items)
        items.map { |item| SignalBoardReading.hazard(item) }.join(", ")
      end

      def quiet(payload)
        r = SignalBoardReading
        position_at = r.optional_time(payload, "position_at")
        return QUIET if position_at.nil?

        now = r.time(payload, "as_of")
        "#{QUIET}\n\n📍 Ви досі там само? Позицію оновлено #{r.day(position_at, now)} — /location"
      end
    end
  end
end
