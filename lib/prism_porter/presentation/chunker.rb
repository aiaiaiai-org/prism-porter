# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Presentation
    class Chunker
      DEFAULT_MAX_CHARS = 3500

      def initialize(max_chars: DEFAULT_MAX_CHARS)
        unless max_chars.is_a?(Integer) && (64..100_000).cover?(max_chars)
          raise InvalidInput, "max_chars must be an integer from 64 to 100000"
        end

        @max_chars = max_chars
      end

      def call(presentation)
        raise InvalidInput, "presentation is required" unless presentation.is_a?(Domain::Presentation)

        texts = split(presentation.text)
        total = texts.length
        texts.each_with_index.map do |text, index|
          Domain::Presentation::Chunk.new(text: text.freeze, position: index + 1, total: total)
        end.freeze
      end

      private

      def split(text)
        chunks = []
        offset = 0
        while offset < text.length
          chunk = text.slice(offset, @max_chars)
          chunks << chunk
          offset += chunk.length
        end
        chunks
      end
    end
  end
end
