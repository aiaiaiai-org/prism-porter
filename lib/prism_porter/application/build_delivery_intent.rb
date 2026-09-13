# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Application
    class BuildDeliveryIntent
      def initialize(route_policy:, renderers:, chunker: Presentation::Chunker.new)
        @route_policy = route_policy
        @renderers = renderers.dup.freeze
        @chunker = chunker
      end

      def call(envelope:)
        raise InvalidInput, "artifact envelope is required" unless envelope.is_a?(Domain::ArtifactEnvelope)

        presentation = renderer_for(envelope).render(envelope)
        Domain::DeliveryIntent.new(
          envelope: envelope,
          context: @route_policy.resolve(envelope),
          presentation: presentation,
          chunks: @chunker.call(presentation)
        )
      end

      private

      def renderer_for(envelope)
        @renderers.fetch(envelope.artifact_kind) do
          raise RendererNotFound, "no renderer for artifact kind"
        end
      end
    end
  end
end
