# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Rendering
    # Renders one person's live board of an attack: every object the sources reported for their
    # zone or their oblast, at the zone first, edited in place as reports come and go.
    #
    # It lists what sources said and when, never which source: the `source` stays in the artifact
    # for audit and is checked, not printed. It never states that a place is
    # safe: when nothing is active it says that the reports ended, not that the sky is clear.
    class SignalBoardRenderer
      SCHEMA = "prism-hub.signal-board.v1".freeze
      MAX_LINES = 20
      MARKS = { "here" => "🔴", "region" => "🟠" }.freeze

      def render(envelope)
        payload = envelope.payload
        raise InvalidArtifact, "unsupported signal board schema" unless payload["schema_version"] == SCHEMA

        Domain::Presentation.new(text: lines(payload).join("\n"))
      end

      private

      def lines(payload)
        entries = SignalBoardReading.list(payload, "entries")
        quiet = SignalBoardReading.list(payload, "quiet")
        return closed(payload) if entries.empty? && quiet.empty?

        ["📡 Повідомлення джерел · з #{clock(SignalBoardReading.time(payload, 'since'))}", "",
         *active(entries), *quiet_block(quiet), *footer(payload)]
      end

      def closed(payload)
        since = clock(SignalBoardReading.time(payload, "since"))
        as_of = clock(SignalBoardReading.time(payload, "as_of"))
        ["📡 Повідомлення джерел · #{since}–#{as_of}",
         "Активних повідомлень немає · завершились: #{ended(payload)}"]
      end

      def active(entries)
        lines = entries.first(MAX_LINES).map { |entry| entry_line(entry) }
        lines << "…і ще #{entries.length - MAX_LINES}" if entries.length > MAX_LINES
        lines
      end

      def quiet_block(quiet)
        return [] if quiet.empty?

        ["", "⏸ Давно без новин:", *quiet.first(MAX_LINES).map { |entry| quiet_line(entry) }]
      end

      def footer(payload)
        count = ended(payload)
        lines = count.positive? ? ["", "✔️ Завершились: #{count}"] : []
        lines << "Оновлено #{clock(SignalBoardReading.time(payload, 'as_of'))}"
      end

      def ended(payload)
        count = payload.fetch("ended", 0)
        raise InvalidArtifact, "signal board ended is invalid" unless count.is_a?(Integer) && count >= 0

        count
      end

      def entry_line(entry)
        r = SignalBoardReading
        mark = MARKS.fetch(r.level(entry))
        line = "#{mark} #{r.hazard(entry)}#{where(entry)} · #{clock(r.time(entry, 'last_seen_at'))}"
        r.source(entry) # checked, never shown
        line += " · без новин" if entry["quiet"] == true
        line
      end

      def quiet_line(entry)
        r = SignalBoardReading
        "#{r.hazard(entry)}#{where(entry)} · востаннє о #{clock(r.time(entry, 'last_seen_at'))}"
      end

      # ` — Чернігів → Київ`, ` — Київська область`, or nothing.
      def where(entry)
        r = SignalBoardReading
        place = r.name(entry, "place")
        target = r.name(entry, "target")
        return "" unless place || target
        return " — #{place}" if target.nil? || target == place
        return " → #{target}" if place.nil?

        " — #{place} → #{target}"
      end

      def clock(time)
        Presentation::KyivTime.clock(time)
      end
    end
  end
end
