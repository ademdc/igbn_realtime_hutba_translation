require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "resolves account by custom domain" do
    assert_equal accounts(:igbd), Account.for_host("hutba.igbd-nuernberg.de")
  end

  test "resolves account by subdomain of APP_DOMAIN" do
    assert_equal accounts(:demo), Account.for_host("demo.localhost")
    assert_equal accounts(:demo), Account.for_host("DEMO.localhost")
  end

  test "returns nil for unknown host and apex domain" do
    assert_nil Account.for_host("unknown.localhost")
    assert_nil Account.for_host("localhost")
  end

  test "falls back to DEFAULT_ACCOUNT_SUBDOMAIN for unrelated hosts" do
    with_env("DEFAULT_ACCOUNT_SUBDOMAIN" => "igbd-nuernberg") do
      assert_equal accounts(:igbd), Account.for_host("hutba.dzamija.net")
      assert_nil Account.for_host("localhost")
    end
  end

  test "validates subdomain format and reserved names" do
    account = Account.new(name: "X", languages: ["de"])

    account.subdomain = "admin"
    assert_not account.valid?

    account.subdomain = "Bad_Name"
    assert_not account.valid?

    account.subdomain = "dzemat-nurnberg"
    assert account.valid?, account.errors.full_messages.to_sentence
  end

  test "rejects unsupported languages" do
    account = Account.new(name: "X", subdomain: "xyz", languages: ["de", "german"])
    assert_not account.valid?
    assert_includes account.errors[:languages].first, "german"
  end

  test "new accounts get a 60 day trial" do
    account = Account.create!(name: "X", subdomain: "xyz", languages: ["de"])
    assert_equal "trialing", account.status
    assert_in_delta 60.days.from_now, account.trial_ends_at, 5.seconds
  end

  test "cannot stream after trial or weekly limit" do
    account = accounts(:demo)
    assert account.can_stream?

    account.speaker_sessions.create!(session_id: "a", started_at: 1.hour.ago, ended_at: Time.current, duration_seconds: 180 * 60)
    assert account.weekly_limit_reached?
    assert_not account.can_stream?

    account.speaker_sessions.delete_all
    account.update!(trial_ends_at: 1.day.ago)
    assert_not account.can_stream?
  end

  test "authenticates speaker PIN per account" do
    assert accounts(:igbd).authenticate_speaker_pin("1234")
    assert_not accounts(:demo).authenticate_speaker_pin("1234")
  end

  private

  def with_env(vars)
    old = vars.keys.index_with { |k| ENV[k] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end
end
