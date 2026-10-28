# Emails owners before a trial or a paid year ends. Run daily: bin/rails billing:reminders
module Billing
  class Reminders
    TRIAL_DAYS = [14, 3, 0].freeze
    RENEWAL_DAYS = [30, 7, 0].freeze

    def self.run(today: Date.current)
      new(today).run
    end

    def initialize(today)
      @today = today
    end

    def run
      sent = 0
      Account.where(status: "trialing").where.not(trial_ends_at: nil).find_each do |account|
        sent += 1 if remind(account, "trial", account.trial_ends_at.to_date, TRIAL_DAYS)
      end
      Account.where(status: "active").where.not(paid_until: nil).find_each do |account|
        sent += 1 if remind(account, "renewal", account.paid_until.to_date, RENEWAL_DAYS)
      end
      sent
    end

    private

    # Sends the most urgent reminder that is due and hasn't been sent for this deadline yet
    def remind(account, kind, deadline, stages)
      days_left = (deadline - @today).to_i
      stage = stages.select { |days| days_left <= days && days_left >= 0 }.min
      return false unless stage

      key = "#{kind}:#{stage}:#{deadline}"
      return false if account.last_reminder == key

      account.users.owners.each do |owner|
        AccountMailer.with(user: owner, kind: kind, days_left: days_left, deadline: deadline).reminder.deliver_later
      end
      account.update_column(:last_reminder, key)
      true
    end
  end
end
