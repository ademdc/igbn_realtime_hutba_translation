class CustomDomainSetupJob < ApplicationJob
  queue_as :default

  def perform(account)
    CustomDomains.setup(account)
  end
end
