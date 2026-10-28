# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "time"

module PrismPorter
  module Rendering
    # The shared vocabulary of `signal.board` and `signal.status`, checked. Anything it does not
    # know is refused, so a renderer never prints a field it could not vouch for.
    module SignalBoardReading
      KINDS = {
        "air.ballistic_missile" => "☄️ балістика",
        "air.missile" => "🚀 ракети",
        "air.jet_drone" => "✈️ реактивні шахеди",
        "air.attack_drone" => "🛵 шахеди",
        "air.guided_bomb" => "💣 КАБи"
      }.freeze
      LEVELS = %w[here region].freeze
      CHANNEL_PATTERN = /\A@[A-Za-z][A-Za-z0-9_]{3,31}\z/
      MAX_COUNT = 100

      module_function

      def time(object, key)
        Time.iso8601(object.fetch(key).to_s)
      rescue ArgumentError, KeyError
        raise InvalidArtifact, "signal board #{key} is not a timestamp"
      end

      def optional_time(object, key)
        object[key].nil? ? nil : time(object, key)
      end

      def kind(object)
        KINDS.fetch(object["kind"]) { raise InvalidArtifact, "signal board kind is unknown" }
      end

      def level(object)
        value = object["level"]
        raise InvalidArtifact, "signal board level is unknown" unless LEVELS.include?(value)

        value
      end

      # `nil` when the source did not say how many.
      def count(object)
        value = object["count"]
        return nil if value.nil?

        valid = value.is_a?(Integer) && value.between?(1, MAX_COUNT)
        raise InvalidArtifact, "signal board count is invalid" unless valid

        value
      end

      def name(object, key)
        value = object[key]
        return nil if value.nil?

        valid = value.is_a?(String) && !value.empty? && value.length <= 120 && !value.match?(/[[:cntrl:]]/)
        raise InvalidArtifact, "signal board #{key} must be short printable text" unless valid

        value
      end

      def source(object)
        value = object["source"]
        return nil if value.nil?

        valid = value.is_a?(String) && CHANNEL_PATTERN.match?(value)
        raise InvalidArtifact, "signal board source is invalid" unless valid

        value
      end

      def list(object, key)
        value = object.fetch(key, [])
        raise InvalidArtifact, "signal board #{key} must be a list" unless value.is_a?(Array)
        raise InvalidArtifact, "signal board #{key} entry is invalid" unless value.all?(Hash)

        value
      end

      # `☄️ балістика ×3`, or without the number when nobody said how many.
      def hazard(object)
        number = count(object)
        number ? "#{kind(object)} ×#{number}" : kind(object)
      end
    end
  end
end
