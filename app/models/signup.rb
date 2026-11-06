# Self-service registration: creates a mosque account on a trial and its first owner.
class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :mosque_name, :string
  attribute :subdomain, :string
  attribute :source_language, :string
  attribute :country, :string
  attribute :city, :string
  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :terms, :boolean
  attribute :locale, :string
  attribute :heard_from, :string
  # Campaign and referrer from the visitor's first page view (see MarketingController)
  attribute :attribution, default: -> { {} }

  validates :terms, acceptance: { accept: true }

  attr_reader :account, :user

  def self.suggest_subdomain(name)
    I18n.transliterate(name.to_s).downcase
      .gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
      .first(40).delete_suffix("-")
  end

  def save
    @account = Account.new(
      name: mosque_name, subdomain: subdomain.presence || self.class.suggest_subdomain(mosque_name),
      country: country.presence, city: city.presence, status: "trialing",
      source_language: source_language.presence || "bs",
      languages: Account.default_languages_for(country),
      heard_from: heard_from.presence,
      **attribution.to_h.symbolize_keys.slice(:utm_source, :utm_medium, :utm_campaign, :referrer_host)
    )
    @user = @account.users.build(
      name: name, email: email, password: password, role: "owner",
      locale: locale, confirmed_at: Time.current
    )

    valid = [valid?, @account.valid?, @user.valid?].all?
    copy_errors
    return false unless valid

    Account.transaction { @account.save! }
    true
  rescue ActiveRecord::RecordNotUnique
    errors.add(:subdomain, :taken)
    false
  end

  private

  def copy_errors
    { name: :mosque_name, subdomain: :subdomain, country: :country, city: :city, source_language: :source_language }.each do |from, to|
      @account.errors[from].each { |message| errors.add(to, message) }
    end
    %i[name email password].each do |attribute|
      @user.errors[attribute].each { |message| errors.add(attribute, message) }
    end
  end
end
