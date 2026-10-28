require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module IgbdTranslationsApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1
    config.hosts << '7cb3beab228d.ngrok-free.app'
    config.hosts << 'igbn-nuernberg-d2981e27b782.herokuapp.com'
    config.hosts << 'hutba.dzamija.net'
    config.hosts << 'dzuma.dzamija.net'
    config.hosts << 'hutba.igbd-nuernberg.de'

    # Tenant subdomains, e.g. dzemat-nurnberg.hutba.app. In development *.localhost is allowed by default.
    if ENV["APP_DOMAIN"].present?
      config.hosts << ENV["APP_DOMAIN"]
      config.hosts << /\A([a-z0-9-]+\.)?#{Regexp.escape(ENV["APP_DOMAIN"])}\z/
    end

    # Mosques' own domains (e.g. hutba.mosque-website.com) are allowed if an account uses them
    config.host_authorization = {
      exclude: ->(request) { request.path == "/up" || Account.custom_domain?(request.host) }
    }

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.i18n.available_locales = %i[de en fr nl bs tr]

    config.x.contact_email = ENV.fetch("CONTACT_EMAIL", "hello@hutba.app")
    config.x.mail_from = ENV.fetch("MAIL_FROM", "Hutba <#{config.x.contact_email}>")

    # Used to build absolute links to mosque subdomains (emails, QR codes)
    config.x.app_protocol = "https"
    config.x.app_port = nil

    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
