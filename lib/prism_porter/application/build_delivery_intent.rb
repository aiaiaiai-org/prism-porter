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
        unless envelope.is_a?(Domain::ArtifactEnvelope)
          raise InvalidInput, "artifact envelope is required"
        end

        context = @route_policy.resolve(envelope)
        renderer = @renderers.fetch(envelope.artifact_kind) do
          raise RendererNotFound, "no renderer for artifact kind"
        end
        presentation = renderer.render(envelope)
        chunks = @chunker.call(presentation)
        Domain::DeliveryIntent.new(
          envelope: envelope,
          context: context,
          presentation: presentation,
          chunks: chunks
        )
      end
    end
  end
end
