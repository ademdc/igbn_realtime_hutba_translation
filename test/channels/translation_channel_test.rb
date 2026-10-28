require "test_helper"

class TranslationChannelTest < ActionCable::Channel::TestCase
  test "listener subscribes to account-scoped stream" do
    stub_connection account: accounts(:demo), connection_uuid: "listener-1", speaker?: false
    with_soniox_stubbed { subscribe language: "nl" }

    assert subscription.confirmed?
    assert_has_stream "translation:#{accounts(:demo).id}:nl"
  end

  test "listener is rejected for a language the account does not offer" do
    stub_connection account: accounts(:demo), connection_uuid: "listener-1", speaker?: false
    subscribe language: "de"
    assert subscription.rejected?
  end

  test "speaker subscription requires speaker session" do
    stub_connection account: accounts(:demo), connection_uuid: "speaker-1", speaker?: false
    subscribe is_speaker: true
    assert subscription.rejected?
  end

  test "authenticated speaker gets account-scoped streams" do
    stub_connection account: accounts(:demo), connection_uuid: "speaker-1", speaker?: true
    subscribe is_speaker: true

    assert subscription.confirmed?
    assert_has_stream "translation_speaker:#{accounts(:demo).id}:speaker-1"
    assert_has_stream "listener_stats:#{accounts(:demo).id}"
    assert_equal 1, accounts(:demo).speaker_sessions.active.count
  end

  test "speaker is rejected when weekly limit is reached" do
    account = accounts(:demo)
    account.speaker_sessions.create!(session_id: "old", started_at: 4.hours.ago, ended_at: 1.hour.ago, duration_seconds: 3 * 3600)

    stub_connection account: account, connection_uuid: "speaker-1", speaker?: true
    subscribe is_speaker: true
    assert subscription.rejected?
  end

  private

  def with_soniox_stubbed
    original = SonioxProxyService.method(:update_active_languages)
    SonioxProxyService.define_singleton_method(:update_active_languages) { |*| }
    yield
  ensure
    SonioxProxyService.define_singleton_method(:update_active_languages, original)
  end
end
