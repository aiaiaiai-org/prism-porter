# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Rendering
    # Renders one person's board: how close the danger is, and every object the sources reported
    # for their zone or their oblast, at the zone first. The hub keeps one board per person,
    # pinned and edited in place; it never goes away, it only goes quiet between attacks.
    #
    # It lists what sources said and when, never which source: the `source` stays in the artifact
    # for audit and is checked, not printed. It never states that a place is safe: a quiet board
    # says there are no new reports, not that the sky is clear. A quiet board is also where an old
    # position is mentioned.
    class SignalBoardRenderer
      SCHEMA = "prism-hub.signal-board.v1".freeze
      MAX_LINES = 20
      MARKS = { "here" => "🔴", "region" => "🟠" }.freeze
      HEADLINES = { "here" => "🔴 Загроза у вашій зоні", "region" => "🟠 Загроза у вашій області",
                    "quiet" => "⚪ Нових повідомлень про загрози немає" }.freeze

      def render(envelope)
        payload = envelope.payload
        raise InvalidArtifact, "unsupported signal board schema" unless payload["schema_version"] == SCHEMA

        Domain::Presentation.new(text: lines(payload).join("\n"))
      end

      private

      def lines(payload)
        entries = SignalBoardReading.list(payload, "entries")
        quiet = SignalBoardReading.list(payload, "quiet")
        level = level(payload, entries)
        lines = [headline(payload, level)]
        lines.push("", *active(entries)) unless entries.empty?
        [*lines, *quiet_block(quiet), *summary(payload, level), *reminder(payload, level), *footer(payload, level)]
      end

      # The hub says how close the danger is; an older hub only lists entries, so it is derived.
      def level(payload, entries)
        level = payload["level"]
        return level if HEADLINES.key?(level)
        raise InvalidArtifact, "signal board level is unknown" unless level.nil?
        return "quiet" if entries.empty?

        entries.any? { |entry| SignalBoardReading.level(entry) == "here" } ? "here" : "region"
      end

      def headline(payload, level)
        since = SignalBoardReading.optional_time(payload, "since")
        return HEADLINES.fetch(level) if level == "quiet" || since.nil?

        "#{HEADLINES.fetch(level)} · з #{clock(since)}"
      end

      # On a quiet board: when the last attack ran and how many objects in it ended.
      def summary(payload, level)
        count = ended(payload)
        since = SignalBoardReading.optional_time(payload, "since")
        return [] unless level == "quiet" && since && count.positive?

        as_of = clock(SignalBoardReading.time(payload, "as_of"))
        ["", "Остання атака: #{clock(since)}–#{as_of} · завершились: #{count}"]
      end

      # On a quiet board, when the hub thinks the position may be old.
      def reminder(payload, level)
        position_at = SignalBoardReading.optional_time(payload, "position_at")
        return [] unless level == "quiet" && position_at

        now = SignalBoardReading.time(payload, "as_of")
        ["", "📍 Позицію оновлено #{SignalBoardReading.day(position_at, now)}. " \
             "Якщо ви вже не там, натисніть «📍 Оновити позицію»."]
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

      def footer(payload, level)
        count = ended(payload)
        lines = level != "quiet" && count.positive? ? ["", "✔️ Завершились: #{count}"] : [""]
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
