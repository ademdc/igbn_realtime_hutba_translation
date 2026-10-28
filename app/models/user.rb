class User < ApplicationRecord
  ROLES = %w[owner speaker].freeze
  PASSWORD_RESET_EXPIRY = 1.hour
  INVITATION_EXPIRY = 7.days

  belongs_to :account, optional: true

  has_secure_password

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { scope: :account_id }
  validates :password, length: { minimum: 10 }, allow_nil: true
  validates :role, inclusion: { in: ROLES }
  validates :account, presence: true, unless: :admin?
  validates :locale, inclusion: { in: MarketingController::LOCALES }, allow_nil: true

  scope :owners, -> { where(role: "owner") }
  scope :admins, -> { where(admin: true) }

  # Tokens become invalid as soon as the password changes, so links are single-use
  generates_token_for :password_reset, expires_in: PASSWORD_RESET_EXPIRY do
    password_salt.last(10)
  end

  generates_token_for :invitation, expires_in: INVITATION_EXPIRY do
    password_salt.last(10)
  end

  # Invited users get an unguessable password until they choose their own
  def self.invite(account:, name:, email:, role:)
    account.users.create(name: name, email: email, role: role, password: SecureRandom.base58(32))
  end

  # The user stored in a Rails session, as long as the password hasn't changed since login
  def self.from_session(user_id, fingerprint)
    user = find_by(id: user_id) if user_id
    user if user && fingerprint.present? &&
      ActiveSupport::SecurityUtils.secure_compare(fingerprint, user.session_fingerprint)
  end

  def owner?
    role == "owner"
  end

  def invitation_pending?
    confirmed_at.nil?
  end

  # Stored in the session so changing the password logs out other devices
  def session_fingerprint
    password_salt.last(10)
  end
end
