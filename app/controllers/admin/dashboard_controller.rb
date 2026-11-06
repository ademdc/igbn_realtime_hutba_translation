module Admin
  class DashboardController < BaseController
    def index
      @accounts_total = Account.count
      @accounts_trialing = Account.trialing.count
      @accounts_paying = Account.paying.count
      @accounts_expired = Account.trial_expired.count
      @accounts_suspended = Account.suspended.count
      @mrr_cents = Account.paying.sum { |account| account.monthly_price_cents }
      decided = @accounts_paying + @accounts_expired
      @conversion = decided.zero? ? nil : (@accounts_paying * 100.0 / decided).round
      @signups_30_days = Account.where(created_at: 30.days.ago..).count

      # Live
      @active_speakers = SpeakerSession.active.includes(:account).to_a
      @active_listeners = ListenerConnection.active.count
      @active_listeners_by_language = ListenerConnection.active_by_language

      # This week
      @week_sessions = SpeakerSession.this_week.count
      @week_listeners = ListenerConnection.this_week.count
      @week_minutes = SpeakerSession.this_week.completed.sum(:duration_seconds) / 60

      @awaiting_transfers = Payment.awaiting_transfer.includes(:account).order(:created_at)
      @signup_sources = Account.signup_sources(since: 90.days.ago)
      @recent_accounts = Account.order(created_at: :desc).limit(8)
      @trials_ending = Account.trialing.where(trial_ends_at: ..14.days.from_now).order(:trial_ends_at).limit(8)
    end

    def reset_speakers
      count = SpeakerSession.active.count
      SpeakerSession.reset_all_active
      redirect_to admin_dashboard_path, notice: "Reset #{count} active speaker session(s)"
    end

    def reset_listeners
      count = ListenerConnection.active.count
      ListenerConnection.reset_all_active
      redirect_to admin_dashboard_path, notice: "Reset #{count} active listener connection(s)"
    end

    def reset_all
      speakers_count = SpeakerSession.active.count
      listeners_count = ListenerConnection.active.count
      SpeakerSession.reset_all_active
      ListenerConnection.reset_all_active
      redirect_to admin_dashboard_path, notice: "Reset #{speakers_count} speaker(s) and #{listeners_count} listener(s)"
    end
  end
end
