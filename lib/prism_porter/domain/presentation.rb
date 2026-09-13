# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Domain
    class Presentation
      Chunk = Data.define(:text, :position, :total) do
        def to_h
          { text: text, position: position, total: total }
        end
      end

      attr_reader :text, :format

      def initialize(text:, format: "plain_text")
        unless text.is_a?(String) && text.valid_encoding? && !text.empty?
          raise InvalidInput, "presentation text must be nonblank UTF-8"
        end
        raise InvalidInput, "unsupported presentation format" unless format == "plain_text"

        @text = text.dup.freeze
        @format = format.freeze
        freeze
      end

      def to_h
        { format: format, text: text }
      end
    end
  end
end
