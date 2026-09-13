# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Domain
    class ArtifactEnvelope
      attr_reader :artifact_kind, :artifact_id, :payload

      def initialize(artifact_kind:, artifact_id:, payload:)
        @artifact_kind = identifier(artifact_kind, "artifact_kind", /\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/)
        @artifact_id = identifier(artifact_id, "artifact_id", /\A[^[:cntrl:]\s]{1,200}\z/)
        @payload = normalize(payload)
        freeze
      end

      private

      def identifier(value, label, pattern)
        raise InvalidInput, "invalid #{label}" unless value.is_a?(String) && value.match?(pattern)

        value.dup.freeze
      end

      def normalize(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, item), result|
            normalized_key = key.to_s
            raise InvalidArtifact, "artifact keys must be nonblank" if normalized_key.empty?
            raise InvalidArtifact, "duplicate normalized artifact key" if result.key?(normalized_key)

            result[normalized_key.freeze] = normalize(item)
          end.freeze
        when Array
          value.map { |item| normalize(item) }.freeze
        when String
          raise InvalidArtifact, "artifact text must be valid UTF-8" unless value.valid_encoding?

          value.dup.freeze
        when Integer, Float, TrueClass, FalseClass, NilClass
          value
        else
          raise InvalidArtifact, "unsupported artifact value"
        end
      end
    end
  end
end
