# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Routing
    class RoutePolicy
      def initialize(routes:)
        raise InvalidInput, "routes must be a nonempty hash" unless routes.is_a?(Hash) && !routes.empty?

        @routes = routes.each_with_object({}) do |(artifact_kind, context), result|
          unless artifact_kind.is_a?(String) && !artifact_kind.empty? && context.is_a?(Domain::LogicalContext)
            raise InvalidInput, "invalid route"
          end

          result[artifact_kind.dup.freeze] = context
        end.freeze
      end

      def resolve(envelope)
        @routes.fetch(envelope.artifact_kind)
      rescue KeyError
        raise RouteNotFound, "no route for artifact kind"
      end
    end
  end
end
