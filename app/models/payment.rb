class Payment < ApplicationRecord
  KINDS = %w[subscription addon].freeze
  STATUSES = %w[pending approved declined].freeze

  belongs_to :account
  belongs_to :user, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :extra_languages, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 20 }

  before_validation :assign_order_number, on: :create

  scope :approved, -> { where(status: "approved") }
  scope :recent, -> { order(created_at: :desc) }

  # One year of service from today or from the end of the current paid period.
  # extra_languages is the total number of add-on languages for that year.
  def self.subscription_for(account, user:, extra_languages:)
    start = [account.paid_until, Time.current].compact.max
    monthly = Account::BASE_PRICE_CENTS + extra_languages * Account::EXTRA_LANGUAGE_PRICE_CENTS
    new(account: account, user: user, kind: "subscription", extra_languages: extra_languages,
        amount_cents: monthly * 12, period_start: start, period_end: start + 1.year)
  end

  # Extra languages during a paid year, charged per started month until paid_until
  def self.addon_for(account, user:, extra_languages:)
    months = account.paid_months_left
    new(account: account, user: user, kind: "addon", extra_languages: extra_languages,
        amount_cents: extra_languages * Account::EXTRA_LANGUAGE_PRICE_CENTS * months,
        period_start: Time.current, period_end: account.paid_until)
  end

  def pending? = status == "pending"
  def approved? = status == "approved"

  def description
    if kind == "subscription"
      "Hutba #{account.name} #{period_start.to_date} – #{period_end.to_date}"
    else
      "Hutba #{account.name} +#{extra_languages} language(s)"
    end
  end

  # Idempotent: the success redirect and the callback may both confirm the same payment
  def approve!(gateway_response = {})
    with_lock do
      return if approved?

      update!(status: "approved", approved_at: Time.current, gateway_response: gateway_response)
      if kind == "subscription"
        account.update!(status: "active", paid_until: period_end, extra_languages: extra_languages)
      else
        account.update!(extra_languages: account.extra_languages + extra_languages)
      end
    end
  end

  def decline!(gateway_response = {})
    with_lock do
      update!(status: "declined", gateway_response: gateway_response) if pending?
    end
  end

  private

  # Monri: 1-40 alphanumeric characters, unique per merchant
  def assign_order_number
    self.order_number ||= "h#{account_id}x#{SecureRandom.alphanumeric(20)}"
  end
end
