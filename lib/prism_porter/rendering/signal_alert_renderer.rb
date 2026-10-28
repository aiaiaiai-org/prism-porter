# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Rendering
    # Renders a Prism Hub signal alert as Ukrainian plain text.
    #
    # The recipient sees the threat, time and safety limitations, not provider names,
    # source IDs or links. Provenance remains in the validated artifact for audit.
    # Retractions describe a withdrawn report, never an official all-clear.
    class SignalAlertRenderer
      TIME_NOTE = "за київським часом".freeze
      DISCLAIMER = "Це неофіційне повідомлення, а не сигнал повітряної тривоги. " \
                   "Орієнтуйтесь на офіційні сповіщення. Відсутність повідомлень не означає безпеки.".freeze

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
        lines.push("Оновлено: #{reading.event_clock} (#{TIME_NOTE})", "", DISCLAIMER)
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
                 "Попереднє повідомлення про загрозу відкликано.",
                 "Це не офіційний відбій. Загрозу не можна вважати знятою лише за цим повідомленням."]
        still = reading.still_active
        lines << "Ще діють повідомлення про цю загрозу: #{still.join(', ')}." unless still.empty?
        lines.push("", "Відсутність повідомлень не означає безпеки.")
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
