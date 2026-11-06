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

  test "custom domains must be real domains outside the app domain" do
    account = accounts(:demo)
    account.custom_domain_enabled = true
    account.custom_domain = "hutba.mosque-website.com"
    assert account.valid?, account.errors.full_messages.to_sentence
    assert_equal "hutba.mosque-website.com", account.host

    account.custom_domain = "not a domain"
    assert_not account.valid?

    account.custom_domain = "evil.localhost"
    assert_not account.valid?
  end

  test "a live custom domain needs the paid add-on" do
    account = accounts(:demo)
    account.custom_domain = "hutba.mosque-website.com"
    assert_not account.valid?
    assert_includes account.errors[:custom_domain].join, "add-on"
  end

  test "own domain adds to the price" do
    assert_equal 2000, accounts(:demo).monthly_price_cents
    assert_equal 2500, accounts(:igbd).monthly_price_cents
  end

  test "knows which custom domains belong to mosques" do
    assert Account.custom_domain?("HUTBA.igbd-nuernberg.de")
    assert_not Account.custom_domain?("example.com")
  end

  test "rejects unsupported languages" do
    account = Account.new(name: "X", subdomain: "xyz", languages: ["de", "german"])
    assert_not account.valid?
    assert_includes account.errors[:languages].first, "german"
  end

  test "new accounts get a 30 day trial" do
    account = Account.create!(name: "X", subdomain: "xyz", languages: ["de"])
    assert_equal "trialing", account.status
    assert_in_delta 30.days.from_now, account.trial_ends_at, 5.seconds
  end

  test "cannot stream past the weekly limit" do
    account = accounts(:demo)
    assert account.can_stream?

    account.speaker_sessions.create!(session_id: "a", started_at: 1.hour.ago, ended_at: Time.current, duration_seconds: 180 * 60)
    assert account.minutes_limit_reached?
    assert_not account.can_stream?
  end

  test "after the trial a mosque keeps broadcasting on the free plan" do
    account = accounts(:demo)
    account.update!(languages: %w[de nl fr])
    account.update!(trial_ends_at: 1.day.ago)

    assert account.free_plan?
    assert account.can_stream?
    assert_equal Account::FREE_MONTHLY_MINUTES, account.minutes_limit
    assert_equal %w[de], account.active_languages
    assert account.offers_language?("de")
    assert_not account.offers_language?("nl")
    # The chosen languages stay, so paying brings them back
    assert_equal %w[de nl fr], account.reload.languages
  end

  test "free plan minutes count per calendar month" do
    account = accounts(:demo)
    account.update!(trial_ends_at: 1.day.ago)

    travel_to Time.current.beginning_of_month + 10.days do
      account.speaker_sessions.create!(session_id: "last-month", started_at: 15.days.ago, ended_at: 15.days.ago, duration_seconds: 80 * 60)
      assert account.can_stream?

      account.speaker_sessions.create!(session_id: "this-month", started_at: 3.days.ago, ended_at: 3.days.ago, duration_seconds: 80 * 60)
      assert account.minutes_limit_reached?
      assert_not account.can_stream?
      assert_equal (Time.current.beginning_of_month + 1.month).to_date, account.minutes_reset_on
    end
  end

  test "an account on the free plan can still be saved with its old languages" do
    account = accounts(:demo)
    account.update!(languages: %w[de nl fr])
    account.update!(trial_ends_at: 1.day.ago)
    assert account.update(name: "Renamed")
    assert_not account.update(languages: %w[de nl])
  end

  test "suspended accounts cannot stream" do
    account = accounts(:demo)
    account.update!(status: "suspended")
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
