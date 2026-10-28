# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Rendering
    # Renders a Prism Hub signal alert as Ukrainian plain text.
    #
    # The recipient sees the threat and its time, not provider names, source IDs or links.
    # Provenance remains in the validated artifact for audit. What the service is, and is not,
    # the person is told once when they start; it is not repeated under every message.
    # A retraction says a report was withdrawn and never that a threat has ended.
    class SignalAlertRenderer
      TIME_NOTE = "за київським часом".freeze

      def render(envelope)
        reading = SignalAlertReading.new(envelope.payload)
        lines = reading.event == "alert" ? alert(reading) : retraction(reading)
        Domain::Presentation.new(text: lines.join("\n"))
      end

      private

      def alert(reading)
        lines = ["⚠️ #{headline(reading)}", *details(reading)]
        reading.sources # Still validate provenance data, without exposing it in the delivery.
        reading.event_url
        lines.push("Оновлено: #{reading.event_clock} (#{TIME_NOTE})")
      end

      def details(reading)
        kinds = reading.kinds
        # Keep validating the legacy band, but never present channel count as a measured
        # probability of harm or independently confirmed local risk.
        reading.likelihood
        [(kinds.empty? ? nil : "Що: #{kinds.join(', ')}")].compact
      end

      def retraction(reading)
        reading.sources # Validate the source metadata without printing it.
        reading.event_url
        lines = ["ℹ️ Уточнення щодо загрози: #{place_line(reading)}",
                 "Оновлено: #{reading.event_clock} (#{TIME_NOTE})",
                 "Попереднє повідомлення про загрозу відкликано."]
        still = reading.still_active
        lines << "Ще діють повідомлення про цю загрозу: #{still.join(', ')}." unless still.empty?
        lines
      end

      def headline(reading)
        label = reading.class_label
        place = reading.place_name
        return place ? "#{label} — #{place}" : label unless reading.nearby?

        place ? "#{label} поруч із #{place}" : "#{label} поблизу"
      end

      def place_line(reading)
        place = reading.place_name
        place ? "#{reading.class_label}, #{place}" : reading.class_label
      end
    end
  end
end
