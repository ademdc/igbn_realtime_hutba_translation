module Admin
  class DashboardController < BaseController
    def index
      # Live stats
      @active_speakers = SpeakerSession.active.count
      @active_listeners = ListenerConnection.active.count
      @active_listeners_by_language = ListenerConnection.active_by_language

      # Today's stats
      @today_sessions = SpeakerSession.today.count
      @today_listeners = ListenerConnection.today.count
      @today_speaking_time = SpeakerSession.today.completed.sum(:duration_seconds)

      # This week's stats
      @week_sessions = SpeakerSession.this_week.count
      @week_listeners = ListenerConnection.this_week.count

      # Recent activity
      @recent_speaker_sessions = SpeakerSession.recent.limit(10)
      @recent_listener_connections = ListenerConnection.recent.limit(20)
    end
  end
end
