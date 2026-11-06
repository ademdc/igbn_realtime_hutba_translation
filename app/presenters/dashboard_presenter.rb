# Numbers shown on the mosque dashboard.
class DashboardPresenter
  attr_reader :account

  def initialize(account)
    @account = account
  end

  def minutes_used
    @minutes_used ||= [account.minutes_used, account.minutes_limit].min
  end

  def minutes_limit
    account.minutes_limit
  end

  def usage_percent
    return 0 if minutes_limit.zero?
    (minutes_used * 100.0 / minutes_limit).round
  end

  def limit_reached?
    account.minutes_limit_reached?
  end

  def resets_on
    account.minutes_reset_on
  end

  def listeners_this_week
    account.listener_connections.this_week.count
  end

  def broadcasts_this_week
    account.speaker_sessions.this_week.count
  end

  def languages_used
    account.active_languages.size
  end
end
