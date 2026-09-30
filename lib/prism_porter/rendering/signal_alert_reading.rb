# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Rendering
    # A `prism-hub.signal-alert.v1` payload, checked. Anything it does not know is refused, so a
    # renderer never prints a field it could not vouch for.
    class SignalAlertReading
      SCHEMA = "prism-hub.signal-alert.v1".freeze
      EVENTS = %w[alert retraction].freeze
      CLASSES = { "drone" => "БпЛА", "bomb" => "КАБи", "missile" => "Ракети" }.freeze
      KINDS = {
        "air.attack_drone" => "ударні дрони",
        "air.jet_drone" => "реактивні дрони",
        "air.ballistic_missile" => "балістичні ракети",
        "air.missile" => "ракети",
        "air.guided_bomb" => "керовані авіабомби"
      }.freeze
      LIKELIHOOD = { "moderate" => "помірна", "high" => "висока" }.freeze
      URL_PATTERN = %r{\Ahttps://t\.me/[A-Za-z0-9_/]{1,200}\z}
      CHANNEL_PATTERN = /\Atelegram\.channel:([A-Za-z][A-Za-z0-9_]{3,31})\z/

      Source = Data.define(:clock, :channel, :url)

      def initialize(payload)
        @payload = payload
        raise InvalidArtifact, "unsupported signal alert schema" unless payload["schema_version"] == SCHEMA
        raise InvalidArtifact, "signal alert event is unknown" unless EVENTS.include?(payload["event"])
      end

      def event
        @payload["event"]
      end

      def class_label
        CLASSES.fetch(hash("hazard")["class"]) { raise InvalidArtifact, "signal alert hazard class is unknown" }
      end

      def kinds
        list = hash("hazard")["kinds"]
        raise InvalidArtifact, "signal alert kinds must be a list" unless list.is_a?(Array)

        list.map { |kind| KINDS.fetch(kind) { raise InvalidArtifact, "signal alert kind is unknown" } }.uniq
      end

      def nearby?
        proximity = @payload["proximity"]
        raise InvalidArtifact, "signal alert proximity is unknown" unless %w[target nearby].include?(proximity)

        proximity == "nearby"
      end

      def likelihood
        value = @payload["likelihood"]
        return nil if value.nil?

        LIKELIHOOD.fetch(value) { raise InvalidArtifact, "signal alert likelihood is unknown" }
      end

      def place_name
        name = hash("place")["name"]
        return nil if name.nil?

        name_text(name, "place name")
      end

      def sources
        list = @payload["sources"]
        raise InvalidArtifact, "signal alert needs at least one source" unless list.is_a?(Array) && !list.empty?

        list.map { |source| source_from(source) }
      end

      def still_active
        list = @payload["still_active"]
        return [] if list.nil?
        raise InvalidArtifact, "signal alert still_active must be a list" unless list.is_a?(Array)

        list.map { |name| name_text(name, "still_active entry") }
      end

      def event_clock
        clock(@payload, "event_at")
      end

      def event_url
        url = @payload["event_url"]
        return nil if url.nil?
        raise InvalidArtifact, "signal alert event_url is invalid" unless url?(url)

        url
      end

      private

      def source_from(source)
        raise InvalidArtifact, "signal alert source is invalid" unless source.is_a?(Hash) && url?(source["url"])

        match = CHANNEL_PATTERN.match(source["source_id"].to_s)
        Source.new(clock: clock(source, "observed_at"), channel: match ? "@#{match[1]}" : "джерело", url: source["url"])
      end

      def clock(object, key)
        Presentation::KyivTime.clock(Time.iso8601(object[key].to_s))
      rescue ArgumentError
        raise InvalidArtifact, "signal alert #{key} is not a timestamp"
      end

      def name_text(value, label)
        valid = value.is_a?(String) && !value.empty? && value.length <= 120 && !value.match?(/[[:cntrl:]]/)
        raise InvalidArtifact, "signal alert #{label} must be short printable text" unless valid

        value
      end

      def url?(value)
        value.is_a?(String) && URL_PATTERN.match?(value)
      end

      def hash(key)
        value = @payload[key]
        raise InvalidArtifact, "signal alert #{key} is missing" unless value.is_a?(Hash)

        value
      end
    end
  end
end
