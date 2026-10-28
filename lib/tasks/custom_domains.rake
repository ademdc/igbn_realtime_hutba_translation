namespace :custom_domains do
  desc "Switch mosque domains live once Heroku has issued their certificate (run every 10 minutes)"
  task check: :environment do
    CustomDomains.check_pending
  end
end
