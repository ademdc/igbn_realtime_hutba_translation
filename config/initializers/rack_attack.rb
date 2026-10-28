# Throttle login, PIN and password-reset attempts to slow down guessing.
Rack::Attack.cache.store =
  if Rails.env.production? && ENV["REDIS_URL"].present?
    ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
  else
    ActiveSupport::Cache::MemoryStore.new
  end

Rack::Attack.enabled = !Rails.env.test?

AUTH_PATHS = %r{\A(/[a-z]{2})?/(login|speaker/authenticate|password_resets|admin/login)\z}

Rack::Attack.throttle("auth/ip", limit: 10, period: 1.minute) do |request|
  request.ip if request.post? && request.path.match?(AUTH_PATHS)
end

Rack::Attack.throttle("auth/email", limit: 5, period: 1.minute) do |request|
  if request.post? && request.path.match?(AUTH_PATHS)
    email = request.params["email"].to_s.strip.downcase.presence
    "#{request.host}:#{email}" if email
  end
end

# The 4-6 digit speaker PIN is the weakest secret: limit per mosque, not just per IP
Rack::Attack.throttle("speaker-pin/host", limit: 20, period: 10.minutes) do |request|
  request.host if request.post? && request.path == "/speaker/authenticate"
end
