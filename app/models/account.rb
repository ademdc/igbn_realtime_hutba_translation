class Account < ApplicationRecord
  RESERVED_SUBDOMAINS = %w[www admin app api mail cable assets static help support status blog].freeze
  STATUSES = %w[trialing active suspended].freeze
  TRIAL_LENGTH = 60.days
  INCLUDED_LANGUAGES = 3
  BASE_PRICE_CENTS = 2000            # per month, billed yearly
  EXTRA_LANGUAGE_PRICE_CENTS = 500   # per extra language per month
  # Endonyms, so the list reads the same in every UI language
  COUNTRY_NAMES = {
    "DE" => "Deutschland", "AT" => "Österreich", "CH" => "Schweiz", "NL" => "Nederland",
    "BE" => "België / Belgique", "FR" => "France", "LU" => "Luxembourg", "DK" => "Danmark",
    "SE" => "Sverige", "NO" => "Norge", "GB" => "United Kingdom", "IT" => "Italia",
    "ES" => "España", "BA" => "Bosna i Hercegovina", "HR" => "Hrvatska", "RS" => "Srbija",
    "ME" => "Crna Gora", "SI" => "Slovenija", "MK" => "Северна Македонија", "AL" => "Shqipëria",
    "XK" => "Kosova", "TR" => "Türkiye", "US" => "United States", "CA" => "Canada", "AU" => "Australia"
  }.freeze
  COUNTRIES = COUNTRY_NAMES.keys.freeze

  has_secure_password :speaker_pin, validations: false

  has_many :speaker_sessions, dependent: :destroy
  has_many :listener_connections, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :payments, dependent: :destroy

  normalizes :subdomain, with: ->(value) { value.to_s.strip.downcase }
  normalizes :custom_domain, with: ->(value) { value.to_s.strip.downcase.presence }

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true, length: { in: 3..63 },
    format: { with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/, message: "may only contain lowercase letters, numbers and hyphens" },
    exclusion: { in: RESERVED_SUBDOMAINS, message: "is reserved" }
  validates :custom_domain, uniqueness: true, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :languages, presence: true
  validates :speaker_pin, format: { with: /\A\d{4,8}\z/ }, allow_nil: true
  validates :country, inclusion: { in: COUNTRIES }, allow_nil: true
  validate :languages_supported
  validate :languages_within_limit

  before_validation :set_trial_end, on: :create

  scope :trialing, -> { where(status: "trialing").where("trial_ends_at IS NULL OR trial_ends_at >= ?", Time.current) }
  scope :trial_expired, -> { where(status: "trialing").where("trial_ends_at < ?", Time.current) }
  scope :paying, -> { where(status: "active") }
  scope :suspended, -> { where(status: "suspended") }
  scope :payment_due, -> { where(status: "active").where("paid_until < ?", Time.current) }

  def self.search(query)
    return all if query.blank?
    pattern = "%#{sanitize_sql_like(query.strip)}%"
    where("accounts.name ILIKE :q OR accounts.subdomain ILIKE :q OR accounts.city ILIKE :q", q: pattern)
  end

  def monthly_price_cents
    BASE_PRICE_CENTS + extra_languages * EXTRA_LANGUAGE_PRICE_CENTS
  end

  # Status as shown to admins, with expired trials split out
  def display_status
    return "trial_expired" if trial_expired?
    return "payment_due" if payment_due?
    status
  end

  # Resolves the tenant for a request host:
  #   1. an exact custom domain (e.g. hutba.igbd-nuernberg.de)
  #   2. a subdomain of APP_DOMAIN (e.g. dzemat-nurnberg.hutba.app)
  #   3. DEFAULT_ACCOUNT_SUBDOMAIN, so pre-multi-tenancy hosts keep working
  def self.for_host(host)
    host = host.to_s.downcase
    return if AppDomain.marketing_host?(host)

    find_by(custom_domain: host) ||
      (host.end_with?(".#{AppDomain.host}") && find_by(subdomain: host.delete_suffix(".#{AppDomain.host}"))) ||
      (ENV["DEFAULT_ACCOUNT_SUBDOMAIN"].present? && find_by(subdomain: ENV["DEFAULT_ACCOUNT_SUBDOMAIN"])) ||
      nil
  end

  def host
    custom_domain || "#{subdomain}.#{AppDomain.host}"
  end

  def url(path = "/")
    AppDomain.url(host, path)
  end

  def offers_language?(code)
    languages.include?(code)
  end

  def language_limit
    INCLUDED_LANGUAGES + extra_languages
  end

  # Listener languages that suit a mosque in this country
  def self.default_languages_for(country)
    case country
    when "DE", "AT", "CH", "LU" then %w[de]
    when "NL" then %w[nl]
    when "BE" then %w[nl fr]
    when "FR" then %w[fr]
    when "IT" then %w[it]
    when "ES" then %w[es]
    when "SE" then %w[sv]
    when "TR" then %w[tr]
    else %w[en]
    end
  end

  def trial_days_left
    return 0 unless status == "trialing" && trial_ends_at
    [(trial_ends_at.to_date - Date.current).to_i, 0].max
  end

  def weekly_minutes_left
    [weekly_minutes_limit - weekly_minutes_used, 0].max
  end

  def suspended?
    status == "suspended"
  end

  def trial_expired?
    status == "trialing" && trial_ends_at.present? && trial_ends_at.past?
  end

  # Paid year ran out (accounts without paid_until, like the original tenant, never expire)
  def payment_due?
    status == "active" && paid_until.present? && paid_until.past?
  end

  def can_stream?
    !suspended? && !trial_expired? && !payment_due? && !weekly_limit_reached?
  end

  def yearly_price_cents
    monthly_price_cents * 12
  end

  # Started months left in the paid year, for prorating add-on languages
  def paid_months_left
    return 0 unless paid_until&.future?

    months = 0
    months += 1 while Time.current + months.months < paid_until && months < 12
    months
  end

  def billing_details_complete?
    [billing_name, billing_address, billing_zip, billing_city, billing_phone, billing_email, country].all?(&:present?)
  end

  def weekly_minutes_used
    speaker_sessions.this_week.sum(
      Arel.sql("COALESCE(duration_seconds, EXTRACT(EPOCH FROM (NOW() - started_at))::integer)")
    ) / 60
  end

  def weekly_limit_reached?
    weekly_minutes_used >= weekly_minutes_limit
  end

  private

  def set_trial_end
    self.trial_ends_at ||= TRIAL_LENGTH.from_now if status == "trialing"
  end

  def languages_within_limit
    if Array(languages).size > language_limit
      errors.add(:languages, :too_many, count: language_limit)
    end
  end

  def languages_supported
    unsupported = Array(languages) - Language::CODES
    errors.add(:languages, "contains unsupported codes: #{unsupported.join(', ')}") if unsupported.any?
  end
end
