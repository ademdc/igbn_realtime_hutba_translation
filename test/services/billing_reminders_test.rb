require "test_helper"

class BillingRemindersTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "sends each trial reminder stage once" do
    account = accounts(:demo)
    account.update!(trial_ends_at: 10.days.from_now)

    assert_enqueued_emails 1 do
      Billing::Reminders.run(today: Date.current)
    end
    assert_no_enqueued_emails do
      Billing::Reminders.run(today: Date.current + 1)
    end
    assert_enqueued_emails 1 do
      Billing::Reminders.run(today: Date.current + 8) # 2 days left
    end
  end

  test "renewal reminder before the paid year ends" do
    account = accounts(:demo)
    account.update!(status: "active", paid_until: 6.days.from_now)
    assert_enqueued_emails 1 do
      Billing::Reminders.run
    end
  end

  test "reminder email renders in the owner's language" do
    user = users(:demo_owner)
    user.update!(locale: "bs")
    mail = AccountMailer.with(user: user, kind: "trial", days_left: 3, deadline: 3.days.from_now.to_date).reminder
    assert_equal "Probni period na Hutbi ističe za 3 dana", mail.subject
    assert_match "/dashboard/billing", mail.text_part.body.to_s
  end
end
