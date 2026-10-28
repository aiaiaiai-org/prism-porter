# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require "test_helper"

class SignalBoardRendererTest < Minitest::Test
  def board(overrides = {})
    {
      "schema_version" => "prism-hub.signal-board.v1",
      "since" => "2026-10-27T01:27:00Z",
      "as_of" => "2026-10-27T01:32:00Z",
      "entries" => [
        { "level" => "here", "kind" => "air.ballistic_missile", "count" => 1, "place" => "Київ",
          "last_seen_at" => "2026-10-27T01:31:00Z", "source" => "@vanek_nikolaev" },
        { "level" => "here", "kind" => "air.jet_drone", "count" => 3, "place" => "Чернігів", "target" => "Київ",
          "last_seen_at" => "2026-10-27T01:29:00Z", "source" => "@kpszsu" },
        { "level" => "region", "kind" => "air.attack_drone", "count" => 4, "place" => "Київська область",
          "last_seen_at" => "2026-10-27T01:20:00Z", "quiet" => true }
      ],
      "quiet" => [
        { "kind" => "air.attack_drone", "count" => nil, "place" => "Бровари", "last_seen_at" => "2026-10-26T22:10:00Z" }
      ],
      "ended" => 2
    }.merge(overrides)
  end

  def status(overrides = {})
    {
      "schema_version" => "prism-hub.signal-status.v1",
      "level" => "here",
      "as_of" => "2026-10-27T01:32:00Z",
      "here" => [{ "kind" => "air.ballistic_missile", "count" => 1 }, { "kind" => "air.jet_drone", "count" => 3 }],
      "region" => [{ "kind" => "air.attack_drone", "count" => 4 }]
    }.merge(overrides)
  end

  def render(kind, payload)
    envelope = PrismPorter::Domain::ArtifactEnvelope.new(artifact_kind: kind, artifact_id: "x", payload: payload)
    renderer = kind == "signal.board" ? PrismPorter::Rendering::SignalBoardRenderer : PrismPorter::Rendering::SignalStatusRenderer
    renderer.new.render(envelope).text
  end

  def test_a_board_lists_objects_at_the_zone_then_the_oblast_then_the_quiet_ones
    expected = <<~TEXT.chomp
      📡 Повідомлення джерел · з 03:27

      🔴 ☄️ балістика ×1 — Київ · 03:31 @vanek_nikolaev
      🔴 ✈️ реактивні шахеди ×3 — Чернігів → Київ · 03:29 @kpszsu
      🟠 🛵 шахеди ×4 — Київська область · 03:20 · без новин

      ⏸ Давно без новин:
      🛵 шахеди — Бровари · востаннє о 00:10

      ✔️ Завершились: 2
      Оновлено 03:32 · неофіційні джерела
    TEXT
    assert_equal expected, render("signal.board", board)
  end

  def test_a_closed_board_says_the_reports_ended_and_never_that_it_is_safe
    text = render("signal.board", board("entries" => [], "quiet" => [], "as_of" => "2026-10-27T03:10:00Z"))
    assert_equal "📡 Повідомлення джерел · 03:27–05:10\nАктивних повідомлень немає · завершились: 2", text
    refute_match(/чист|безпечн|відбій/i, text)
  end

  def test_a_long_board_is_bounded
    many = Array.new(60) do |i|
      { "level" => "here", "kind" => "air.attack_drone", "count" => 1, "place" => "Місце #{i}",
        "last_seen_at" => "2026-10-27T01:31:00Z" }
    end
    text = render("signal.board", board("entries" => many))
    assert_includes text, "…і ще 40"
    assert_operator text.length, :<, 4096
  end

  def test_a_status_rings_with_what_and_how_many
    expected = <<~TEXT.chomp
      🔴 Загроза у вашій зоні

      ☄️ балістика ×1
      ✈️ реактивні шахеди ×3
      🟠 на вашу область: 🛵 шахеди ×4

      Неофіційні джерела. Орієнтуйтеся на повітряну тривогу.
    TEXT
    assert_equal expected, render("signal.status", status)
    region = render("signal.status", status("level" => "region", "here" => []))
    assert region.start_with?("🟠 Загроза у вашій області\n\n🛵 шахеди ×4")
    unknown = render("signal.status", status("here" => [{ "kind" => "air.attack_drone", "count" => nil }]))
    assert_includes unknown, "\n🛵 шахеди\n"
  end

  def test_a_quiet_status_is_never_an_all_clear_and_may_remind_of_an_old_position
    quiet = render("signal.status", status("level" => "quiet", "here" => [], "region" => []))
    assert quiet.start_with?("⚪ Джерела затихли")
    assert_includes quiet, "Це не відбій"
    refute_match(/чист|безпечн/i, quiet)
    refute_includes quiet, "📍"

    saturday = render("signal.status", status("level" => "quiet", "here" => [], "region" => [],
                                              "as_of" => "2026-10-27T10:00:00Z",
                                              "position_at" => "2026-10-24T09:34:00Z"))
    assert saturday.end_with?("📍 Ви досі там само? Позицію оновлено в суботу о 12:34 — /location"), saturday
    old = render("signal.status", status("level" => "quiet", "here" => [], "region" => [],
                                         "as_of" => "2026-10-27T10:00:00Z", "position_at" => "2026-10-10T09:34:00Z"))
    assert_includes old, "оновлено 10.10 о 12:34"
  end

  def test_it_fails_closed_on_anything_it_does_not_know
    at = { "last_seen_at" => "2026-10-27T01:31:00Z" }
    drone = at.merge("level" => "here", "kind" => "air.attack_drone")
    [
      ["signal.board", board("schema_version" => "prism-hub.signal-board.v2")],
      ["signal.board", board("entries" => [drone.merge("kind" => "air.balloon")])],
      ["signal.board", board("entries" => [drone.merge("level" => "near")])],
      ["signal.board", board("entries" => [drone.merge("count" => 0)])],
      ["signal.board", board("entries" => [drone.merge("place" => "Київ\u0007")])],
      ["signal.board", board("entries" => [drone.merge("source" => "https://evil")])],
      ["signal.board", board("since" => "soon")],
      ["signal.status", status("level" => "safe")],
      ["signal.status", status("here" => [])],
      ["signal.status", status("schema_version" => "x")]
    ].each do |kind, payload|
      assert_raises(PrismPorter::InvalidArtifact, payload.inspect) { render(kind, payload) }
    end
  end

  def test_both_are_reachable_through_the_worker_contract
    %w[signal.board signal.status].each do |kind|
      payload = kind == "signal.board" ? board : status
      request = {
        "schema_version" => "prism-porter.request.v1",
        "artifact" => { "artifact_kind" => kind, "artifact_id" => "a1", "payload" => payload },
        "routes" => [{ "artifact_kind" => kind, "logical_context" => { "workspace" => "w", "channel" => "alerts" } }]
      }
      out = StringIO.new
      input = StringIO.new(JSON.generate(request))
      assert_equal 0, PrismPorter::CLI.run(input: input, output: out, errors: StringIO.new)
      assert_includes out.string, "Повідомлення джерел" if kind == "signal.board"
    end
  end
end
