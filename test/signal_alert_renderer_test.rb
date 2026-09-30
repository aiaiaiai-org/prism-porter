# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "test_helper"

class SignalAlertRendererTest < Minitest::Test
  def payload(overrides = {})
    {
      "schema_version" => "prism-hub.signal-alert.v1",
      "event" => "alert",
      "hazard" => { "class" => "drone", "kinds" => ["air.attack_drone"] },
      "place" => { "name" => "Київ" },
      "proximity" => "target",
      "likelihood" => "moderate",
      "first_reported_at" => "2026-09-30T11:59:00Z",
      "valid_until" => "2026-09-30T12:29:00Z",
      "event_at" => "2026-09-30T11:59:00Z",
      "event_url" => "https://t.me/vanek_nikolaev/43222",
      "sources" => [
        { "source_id" => "telegram.channel:vanek_nikolaev", "url" => "https://t.me/vanek_nikolaev/43220",
          "observed_at" => "2026-09-30T11:57:00Z" },
        { "source_id" => "telegram.channel:vanek_nikolaev", "url" => "https://t.me/vanek_nikolaev/43222",
          "observed_at" => "2026-09-30T11:59:00Z" }
      ],
      "still_active" => []
    }.merge(overrides)
  end

  def render(overrides = {})
    envelope = PrismPorter::Domain::ArtifactEnvelope.new(
      artifact_kind: "signal.alert", artifact_id: "signal-alert-1", payload: payload(overrides)
    )
    PrismPorter::Rendering::SignalAlertRenderer.new.render(envelope).text
  end

  def test_an_alert_names_the_hazard_the_place_the_source_and_the_time
    expected = <<~TEXT.chomp
      ⚠️ БпЛА — Київ
      Що: ударні дрони
      Ймовірність: помірна

      Повідомляли (Telegram, за київським часом):
      • 14:57 — @vanek_nikolaev https://t.me/vanek_nikolaev/43220
      • 14:59 — @vanek_nikolaev https://t.me/vanek_nikolaev/43222

      Це неофіційне джерело, а не повітряна тривога. Стежте за офіційними оповіщеннями. Відсутність повідомлень не означає безпеки.
    TEXT

    assert_equal expected, render
  end

  def test_a_nearby_report_says_so
    assert_includes render("proximity" => "nearby").lines.first, "БпЛА поруч із Київ"
    assert_includes render("proximity" => "nearby", "place" => { "name" => nil }).lines.first, "БпЛА поблизу"
    assert_equal "⚠️ БпЛА\n", render("place" => { "name" => nil }).lines.first
  end

  def test_every_class_and_kind_has_its_own_words
    text = render("hazard" => { "class" => "missile", "kinds" => %w[air.ballistic_missile air.missile] })

    assert_includes text, "⚠️ Ракети — Київ"
    assert_includes text, "Що: балістичні ракети, ракети"
    assert_includes render("hazard" => { "class" => "bomb", "kinds" => ["air.guided_bomb"] }), "КАБи — Київ"
  end

  def test_the_likelihood_is_omitted_when_the_artifact_has_none
    refute_includes render("likelihood" => nil), "Ймовірність"
    assert_includes render("likelihood" => "high"), "Ймовірність: висока"
  end

  def test_an_alert_never_speaks_of_an_end
    text = render.downcase

    refute_includes text, "відбій"
    refute_includes text, "безпечно"
    refute_includes text, "valid_until"
  end

  def test_a_retraction_says_the_source_called_it_off_and_that_this_is_not_official
    expected = <<~TEXT.chomp
      ℹ️ Джерело повідомило про відбій: БпЛА, Київ
      14:59 (за київським часом) джерело написало, що цю загрозу знято. https://t.me/vanek_nikolaev/43222
      Це не офіційний відбій.

      Відсутність повідомлень не означає безпеки.
    TEXT

    assert_equal expected, render("event" => "retraction")
  end

  def test_a_retraction_names_reports_that_still_cover_the_person
    text = render("event" => "retraction", "still_active" => %w[Бровари Ірпінь])

    assert_includes text, "Ще діють повідомлення про цю загрозу: Бровари, Ірпінь."
    assert_includes text, "Це не офіційний відбій."
  end

  def test_a_retraction_without_a_link_still_renders
    text = render("event" => "retraction", "event_url" => nil)

    assert_includes text, "джерело написало, що цю загрозу знято.\n"
  end

  def test_time_follows_ukrainian_daylight_saving
    summer = render("sources" => [source("2026-07-01T10:00:00Z")])
    winter = render("sources" => [source("2026-12-01T10:00:00Z")])

    assert_includes summer, "• 13:00"
    assert_includes winter, "• 12:00"
  end

  def test_the_daylight_saving_switches_at_0100_utc_on_the_last_sunday
    assert_equal 2, PrismPorter::Presentation::KyivTime.offset_hours(Time.utc(2026, 3, 29, 0, 59))
    assert_equal 3, PrismPorter::Presentation::KyivTime.offset_hours(Time.utc(2026, 3, 29, 1, 0))
    assert_equal 3, PrismPorter::Presentation::KyivTime.offset_hours(Time.utc(2026, 10, 25, 0, 59))
    assert_equal 2, PrismPorter::Presentation::KyivTime.offset_hours(Time.utc(2026, 10, 25, 1, 0))
  end

  def test_the_same_artifact_renders_the_same_text
    assert_equal render, render
  end

  def test_it_fails_closed_on_anything_it_does_not_know
    bad = [
      { "schema_version" => "prism-hub.signal-alert.v2" },
      { "event" => "expired" },
      { "event" => nil },
      { "hazard" => { "class" => "laser", "kinds" => [] } },
      { "hazard" => { "class" => "drone", "kinds" => ["air.ufo"] } },
      { "hazard" => nil },
      { "proximity" => "inside" },
      { "likelihood" => "certain" },
      { "place" => { "name" => "Ки\nїв" } },
      { "sources" => [] },
      { "sources" => [{ "source_id" => "x", "url" => "javascript:alert(1)",
                        "observed_at" => "2026-09-30T11:57:00Z" }] },
      { "sources" => [{ "source_id" => "x", "url" => "https://evil.example/x",
                        "observed_at" => "2026-09-30T11:57:00Z" }] },
      { "sources" => [source("yesterday")] },
      { "event" => "retraction", "event_at" => nil },
      { "event" => "retraction", "event_url" => "http://t.me/x/1" },
      { "event" => "retraction", "still_active" => "Бровари" }
    ]

    bad.each do |overrides|
      assert_raises(PrismPorter::InvalidArtifact, overrides.inspect) { render(overrides) }
    end
  end

  def test_a_source_that_is_not_a_telegram_channel_is_named_generically
    text = render("sources" => [source("2026-09-30T11:57:00Z", source_id: "rss:whatever")])

    assert_includes text, "• 14:57 — джерело https://t.me/"
  end

  def test_it_builds_a_delivery_intent_through_the_worker_contract
    input = StringIO.new(JSON.generate(
                           "schema_version" => "prism-porter.request.v1",
                           "artifact" => { "artifact_kind" => "signal.alert", "artifact_id" => "signal-alert-1",
                                           "payload" => payload },
                           "routes" => [{ "artifact_kind" => "signal.alert",
                                          "logical_context" => { "workspace" => "personal-a", "channel" => "alerts" } }]
                         ))
    output = StringIO.new

    status = PrismPorter::CLI.run(input: input, output: output, errors: StringIO.new)
    intent = JSON.parse(output.string)

    assert_equal 0, status
    assert_equal "signal.alert", intent.fetch("artifact_kind")
    assert_equal({ "workspace" => "personal-a", "channel" => "alerts" }, intent.fetch("logical_context"))
    assert_includes intent.fetch("chunks").map { |chunk| chunk.fetch("text") }.join, "БпЛА — Київ"
  end

  private

  def source(observed_at, source_id: "telegram.channel:vanek_nikolaev")
    { "source_id" => source_id, "url" => "https://t.me/vanek_nikolaev/1", "observed_at" => observed_at }
  end
end
