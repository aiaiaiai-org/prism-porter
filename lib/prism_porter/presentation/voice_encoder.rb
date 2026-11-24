# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "tmpdir"
require "timeout"

module PrismPorter
  module Presentation
    class VoiceEncodingError < Error; end

    # A transient audio value; never insert into the text DeliveryIntent or CLI.
    class Voice
      PROFILE = "voice.ogg-opus.v1".freeze
      attr_reader :bytes

      def initialize(bytes:)
        @bytes = bytes.b.freeze
        freeze
      end

      def profile = PROFILE
      def media_type = "audio/ogg"
      def kind = "voice"
      def inspect = "#<PrismPorter::Presentation::Voice redacted>"
      def to_json(*) = raise(InvalidInput, "transient voice cannot be serialized")
      def _dump(*) = raise(InvalidInput, "transient voice cannot be serialized")
    end

    # Profile selection belongs to the orchestrator. No provider coordinates,
    # credentials, HTTP, delivery, or product-specific privacy policy live here.
    class VoiceEncoder
      MAX_BYTES = 10 * 1024 * 1024
      TIMEOUT_SECONDS = 20

      def initialize(ffmpeg: "/usr/bin/ffmpeg")
        unless ffmpeg.is_a?(String) && ffmpeg.start_with?("/") && File.file?(ffmpeg) && File.executable?(ffmpeg)
          raise InvalidInput, "voice encoder unavailable"
        end

        @ffmpeg = ffmpeg.dup.freeze
      end

      def call(wav:, profile:)
        raise InvalidInput, "unsupported voice profile" unless profile == Voice::PROFILE

        PcmWave.validate!(wav)
        Dir.mktmpdir("prism-voice-") do |directory|
          input = File.join(directory, "speech.wav")
          output = File.join(directory, "voice.ogg")
          File.binwrite(input, wav)
          encode(input, output)
          Voice.new(bytes: read_output(output))
        end
      rescue SystemCallError
        raise VoiceEncodingError, "voice encoding failed", cause: nil
      end

      private

      def arguments(input, output)
        ["-nostdin", "-v", "error", "-f", "wav", "-i", input,
         "-map", "0:a:0", "-map_metadata", "-1", "-map_chapters", "-1",
         "-c:a", "libopus", "-b:a", "32k", "-ac", "1", "-ar", "48000",
         "-f", "ogg", output]
      end

      def encode(input, output)
        pid = Process.spawn(@ffmpeg, *arguments(input, output), in: File::NULL,
                            out: File::NULL, err: File::NULL, rlimit_fsize: [MAX_BYTES + 1, MAX_BYTES + 1])
        status = Timeout.timeout(TIMEOUT_SECONDS) { Process.wait2(pid).last }
        raise VoiceEncodingError, "voice encoding failed" unless status.success?
      rescue Timeout::Error
        terminate(pid)
        raise VoiceEncodingError, "voice encoding timeout", cause: nil
      end

      def terminate(pid)
        Process.kill("KILL", pid)
      rescue Errno::ESRCH
        nil
      ensure
        begin
          Process.wait(pid)
        rescue Errno::ECHILD
          nil
        end
      end

      def read_output(path)
        raise VoiceEncodingError, "voice output exceeds limit" if File.size(path) > MAX_BYTES

        bytes = File.binread(path)
        unless bytes.start_with?("OggS") && bytes.byteslice(0, 256).include?("OpusHead")
          raise VoiceEncodingError, "invalid voice output"
        end

        bytes
      end
    end
  end
end
