class SpeakerSession < ApplicationRecord
  validates :session_id, presence: true
  validates :started_at, presence: true

  scope :active, -> { where(ended_at: nil) }
  scope :completed, -> { where.not(ended_at: nil) }
  scope :today, -> { where(started_at: Time.current.beginning_of_day..) }
  scope :this_week, -> { where(started_at: Time.current.beginning_of_week..) }
  scope :recent, -> { order(started_at: :desc) }

  def self.start_session(session_id)
    create!(session_id: session_id, started_at: Time.current)
  end

  def end_session(word_count: 0)
    return if ended_at.present?

    update!(
      ended_at: Time.current,
      duration_seconds: (Time.current - started_at).to_i,
      word_count: word_count
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
