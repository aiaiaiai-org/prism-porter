# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Domain
    class LogicalContext
      attr_reader :workspace, :channel

      def initialize(workspace:, channel:)
        @workspace = identifier(workspace, "workspace")
        @channel = identifier(channel, "channel")
        freeze
      end

      def to_h
        { workspace: workspace, channel: channel }
      end

      def ==(other)
        other.is_a?(LogicalContext) && other.to_h == to_h
      end

      alias eql? ==

      def hash
        to_h.hash
      end

      private

      def identifier(value, label)
        unless value.is_a?(String) && value.match?(/\A[^[:cntrl:]]{1,100}\z/) && !value.strip.empty?
          raise InvalidInput, "#{label} must be a nonblank logical identifier"
        end

        value.strip.freeze
      end
    end
  end
end
