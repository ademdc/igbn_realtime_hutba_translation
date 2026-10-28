class Account < ApplicationRecord
  RESERVED_SUBDOMAINS = %w[www admin app api mail cable assets static help support status blog].freeze
  STATUSES = %w[trialing active suspended].freeze
  TRIAL_LENGTH = 60.days

  has_secure_password :speaker_pin, validations: false

  has_many :speaker_sessions, dependent: :destroy
  has_many :listener_connections, dependent: :destroy

  normalizes :subdomain, with: ->(value) { value.to_s.strip.downcase }
  normalizes :custom_domain, with: ->(value) { value.to_s.strip.downcase.presence }

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true, length: { in: 3..63 },
    format: { with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/, message: "may only contain lowercase letters, numbers and hyphens" },
    exclusion: { in: RESERVED_SUBDOMAINS, message: "is reserved" }
  validates :custom_domain, uniqueness: true, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :languages, presence: true
  validate :languages_supported

  before_validation :set_trial_end, on: :create

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

  def offers_language?(code)
    languages.include?(code)
  end

  def suspended?
    status == "suspended"
  end

  def trial_expired?
    status == "trialing" && trial_ends_at.present? && trial_ends_at.past?
  end

  def can_stream?
    !suspended? && !trial_expired? && !weekly_limit_reached?
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

  def languages_supported
    unsupported = Array(languages) - Language::CODES
    errors.add(:languages, "contains unsupported codes: #{unsupported.join(', ')}") if unsupported.any?
  end
end
