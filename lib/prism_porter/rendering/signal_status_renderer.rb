# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "date"

module PrismPorter
  module Rendering
    # Renders one person's status line: how close the danger is, and what.
    #
    # The hub decides when it rings; this only says it. A quiet status says the sources went
    # quiet and that this is not an all-clear, and it is the one place a stale position is
    # mentioned. Nothing here says a place is safe.
    class SignalStatusRenderer
      SCHEMA = "prism-hub.signal-status.v1".freeze
      LEVELS = %w[here region quiet].freeze
      NOTE = "Неофіційні джерела. Орієнтуйтеся на повітряну тривогу.".freeze
      QUIET = "⚪ Джерела затихли\nАктивних повідомлень для вашої зони немає. " \
              "Це не відбій: орієнтуйтеся на повітряну тривогу.".freeze
      HEADLINES = { "here" => "🔴 Загроза у вашій зоні", "region" => "🟠 Загроза у вашій області" }.freeze
      WEEKDAYS = ["в неділю", "в понеділок", "у вівторок", "в середу", "в четвер", "в пʼятницю",
                  "в суботу"].freeze

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
        lines.push("", NOTE).join("\n")
      end

      def hazards(items)
        items.map { |item| SignalBoardReading.hazard(item) }.join(", ")
      end

      def quiet(payload)
        r = SignalBoardReading
        position_at = r.optional_time(payload, "position_at")
        return QUIET if position_at.nil?

        now = r.time(payload, "as_of")
        "#{QUIET}\n\n📍 Ви досі там само? Позицію оновлено #{day(position_at, now)} — /location"
      end

      # `в суботу о 12:34`, `вчора о 12:34`, or `24.10 о 12:34` when more than a week ago.
      def day(at, now)
        days = (local(now).to_date - local(at).to_date).to_i
        "#{date(days, local(at))} о #{Presentation::KyivTime.clock(at)}"
      end

      def date(days, local_at)
        case days
        when 0 then "сьогодні"
        when 1 then "вчора"
        when 2..6 then WEEKDAYS.fetch(local_at.wday)
        else local_at.strftime("%d.%m")
        end
      end

      def local(time)
        time.utc + (Presentation::KyivTime.offset_hours(time) * 3600)
      end
    end
  end
end
