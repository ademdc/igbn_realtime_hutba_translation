class ListenerConnection < ApplicationRecord
  validates :session_id, presence: true
  validates :language, presence: true
  validates :connected_at, presence: true

  scope :active, -> { where(disconnected_at: nil) }
  scope :completed, -> { where.not(disconnected_at: nil) }
  scope :today, -> { where(connected_at: Time.current.beginning_of_day..) }
  scope :this_week, -> { where(connected_at: Time.current.beginning_of_week..) }
  scope :recent, -> { order(connected_at: :desc) }
  scope :by_language, ->(lang) { where(language: lang) }

  def self.start_connection(session_id, language)
    create!(session_id: session_id, language: language, connected_at: Time.current)
  end

  def self.active_by_language
    active.group(:language).count
  end

  def end_connection
    return if disconnected_at.present?

    update!(
      disconnected_at: Time.current,
      duration_seconds: (Time.current - connected_at).to_i
    )
  end

  def duration_formatted
    return "Active" unless duration_seconds

    hours = duration_seconds / 3600
    minutes = (duration_seconds % 3600) / 60
    seconds = duration_seconds % 60

    if hours > 0
      format("%dh %dm %ds", hours, minutes, seconds)
    elsif minutes > 0
      format("%dm %ds", minutes, seconds)
    else
      format("%ds", seconds)
    end
  end
end
