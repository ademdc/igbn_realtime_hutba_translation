namespace :billing do
  desc "Email trial-ending and renewal reminders (run daily)"
  task reminders: :environment do
    puts "Reminders sent for #{Billing::Reminders.run} account(s)"
  end
end
