# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require_relative "test_helper"
require "json"
require "open3"

class VoiceEncoderTest < Minitest::Test
  def wave(samples: 8000, rate: 8000)
    data = "\0\0".b * samples
    format = [1, 1, rate, rate * 2, 2, 16].pack("vvVVvv")
    chunks = "fmt ".b + [format.bytesize].pack("V") + format + "data".b + [data.bytesize].pack("V") + data
    "RIFF".b + [chunks.bytesize + 4].pack("V") + "WAVE".b + chunks
  end

  def test_real_ogg_opus_encoding_and_metadata
    voice = PrismPorter::Presentation::VoiceEncoder.new.call(wav: wave, profile: "voice.ogg-opus.v1")
    assert_equal "audio/ogg", voice.media_type
    assert_equal "voice", voice.kind
    assert voice.bytes.start_with?("OggS")
    info, status = Open3.capture2("/usr/bin/ffprobe", "-v", "error", "-show_streams", "-show_format",
                                  "-of", "json", "-i", "pipe:0", stdin_data: voice.bytes, binmode: true)
    assert status.success?
    stream = JSON.parse(info).fetch("streams").fetch(0)
    assert_equal "opus", stream.fetch("codec_name")
    assert_equal 1, stream.fetch("channels")
    assert_equal "48000", stream.fetch("sample_rate")
    assert_equal "#<PrismPorter::Presentation::Voice redacted>", voice.inspect
    assert_raises(PrismPorter::InvalidInput) { JSON.generate(voice) }
    assert_raises(PrismPorter::InvalidInput) { Marshal.dump(voice) }
  end

  def test_rejects_unknown_profile_and_bad_wav
    encoder = PrismPorter::Presentation::VoiceEncoder.new
    assert_raises(PrismPorter::InvalidInput) { encoder.call(wav: wave, profile: "other") }
    assert_raises(PrismPorter::InvalidArtifact) { encoder.call(wav: "secret", profile: "voice.ogg-opus.v1") }
    assert_raises(PrismPorter::InvalidArtifact) { encoder.call(wav: wave.byteslice(0, 50), profile: "voice.ogg-opus.v1") }
  end

  def test_rejects_excess_duration_without_truncating
    assert_raises(PrismPorter::InvalidArtifact) do
      PrismPorter::Presentation::PcmWave.validate!(wave(samples: 2_400_001))
    end
  end

  def test_missing_encoder
    assert_raises(PrismPorter::InvalidInput) do
      PrismPorter::Presentation::VoiceEncoder.new(ffmpeg: "/missing/ffmpeg")
    end
  end
end
