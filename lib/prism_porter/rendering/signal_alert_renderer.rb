# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Rendering
    # Renders a Prism Hub signal alert as Ukrainian plain text.
    #
    # The text says what a report claimed, who made it, and when, and says plainly that the source
    # is unofficial. It shows only what the artifact holds. It never states that a place is safe:
    # a retraction reports that the source called a threat off, and a missing message is not an
    # all-clear.
    class SignalAlertRenderer
      TIME_NOTE = "за київським часом".freeze
      DISCLAIMER = "Це неофіційне джерело, а не повітряна тривога. Стежте за офіційними оповіщеннями. " \
                   "Відсутність повідомлень не означає безпеки.".freeze

      def render(envelope)
        reading = SignalAlertReading.new(envelope.payload)
        lines = reading.event == "alert" ? alert(reading) : retraction(reading)
        Domain::Presentation.new(text: lines.join("\n"))
      end

      private

      def alert(reading)
        lines = ["⚠️ #{headline(reading)}", *details(reading)]
        lines.push("", "Повідомляли (Telegram, #{TIME_NOTE}):")
        lines.concat(reading.sources.map { |source| "• #{source.clock} — #{source.channel} #{source.url}" })
        lines.push("", DISCLAIMER)
      end

      def details(reading)
        kinds = reading.kinds
        likelihood = reading.likelihood
        [(kinds.empty? ? nil : "Що: #{kinds.join(', ')}"), likelihood && "Ймовірність: #{likelihood}"].compact
      end

      def retraction(reading)
        said = "джерело написало, що цю загрозу знято."
        link = reading.event_url ? " #{reading.event_url}" : ""
        lines = ["ℹ️ Джерело повідомило про відбій: #{place_line(reading)}",
                 "#{reading.event_clock} (#{TIME_NOTE}) #{said}#{link}",
                 "Це не офіційний відбій."]
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
