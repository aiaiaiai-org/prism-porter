# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Presentation
    # The synthesis boundary supplies PCM16 WAV, not arbitrary media containers.
    module PcmWave
      MAX_BYTES = 60 * 1024 * 1024
      MAX_SECONDS = 300
      module_function

      def validate!(bytes)
        unless bytes.is_a?(String) && bytes.bytesize.between?(44, MAX_BYTES) &&
               bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WAVE" &&
               bytes.byteslice(4, 4).unpack1("V") == bytes.bytesize - 8
          raise InvalidArtifact, "invalid speech WAV"
        end

        chunks = read_chunks(bytes)
        validate_pcm(chunks)
      end

      def read_chunks(bytes)
        chunks = {}
        offset = 12
        while offset < bytes.bytesize
          type, size = chunk_header(bytes, offset)
          offset += 8
          raise InvalidArtifact, "invalid WAV chunk" if offset + size > bytes.bytesize || chunks.key?(type)

          chunks[type] = type == "fmt " ? bytes.byteslice(offset, size) : size
          offset += size + (size % 2)
        end
        raise InvalidArtifact, "invalid WAV padding" unless offset == bytes.bytesize

        chunks
      end

      def chunk_header(bytes, offset)
        header = bytes.byteslice(offset, 8)
        raise InvalidArtifact, "invalid WAV chunk" unless header&.bytesize == 8

        type, size = header.unpack("a4V")
        raise InvalidArtifact, "unsupported WAV chunk" unless ["fmt ", "data"].include?(type)

        [type, size]
      end

      def validate_pcm(chunks)
        format = chunks["fmt "]
        size = chunks["data"]
        raise InvalidArtifact, "missing WAV PCM data" unless format&.bytesize == 16 && size&.positive?

        codec, channels, rate, byte_rate, alignment, bits = format.unpack("vvVVvv")
        unless codec == 1 && bits == 16 && [1, 2].include?(channels) && rate.between?(8_000, 48_000) &&
               alignment == channels * 2 && byte_rate == rate * alignment && (size % alignment).zero?
          raise InvalidArtifact, "unsupported WAV PCM format"
        end

        raise InvalidArtifact, "speech duration exceeds limit" if size > byte_rate * MAX_SECONDS

        size.fdiv(byte_rate)
      end
    end
  end
end
