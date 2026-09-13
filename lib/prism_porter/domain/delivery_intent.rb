# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "digest"

module PrismPorter
  module Domain
    class DeliveryIntent
      attr_reader :artifact_id, :artifact_kind, :context, :presentation, :chunks, :idempotency_key

      def initialize(envelope:, context:, presentation:, chunks:)
        raise InvalidInput, "delivery context is required" unless context.is_a?(LogicalContext)

        raise InvalidInput, "presentation is required" unless presentation.is_a?(Presentation)

        validate_chunks(chunks, presentation)
        @artifact_id = envelope.artifact_id
        @artifact_kind = envelope.artifact_kind
        @context = context
        @presentation = presentation
        @chunks = chunks.dup.freeze
        @idempotency_key = fingerprint.freeze
        freeze
      end

      def to_h
        {
          artifact_id: artifact_id,
          artifact_kind: artifact_kind,
          logical_context: context.to_h,
          presentation: { format: presentation.format },
          chunks: chunks.map(&:to_h),
          idempotency_key: idempotency_key
        }
      end

      private

      def validate_chunks(value, full_presentation)
        valid = chunk_collection?(value) &&
                chunks_reconstruct?(value, full_presentation) &&
                positions_valid?(value)
        raise InvalidInput, "invalid presentation chunks" unless valid
      end

      def chunk_collection?(value)
        value.is_a?(Array) && !value.empty? && value.all? { |chunk| chunk.is_a?(Presentation::Chunk) }
      end

      def chunks_reconstruct?(value, full_presentation)
        value.map(&:text).join == full_presentation.text
      end

      def positions_valid?(value)
        value.each_with_index.all? do |chunk, index|
          chunk.position == index + 1 && chunk.total == value.length
        end
      end

      def fingerprint
        Digest::SHA256.hexdigest([
          artifact_kind,
          artifact_id,
          context.workspace,
          context.channel,
          presentation.format,
          presentation.text
        ].join("\0"))
      end
    end
  end
end
