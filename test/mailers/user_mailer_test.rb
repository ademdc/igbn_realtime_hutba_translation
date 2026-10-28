require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "password reset links to the mosque subdomain in the user's language" do
    user = users(:demo_owner)
    user.update!(locale: "bs")
    mail = UserMailer.with(user: user).password_reset

    assert_equal ["owner@demo.test"], mail.to
    assert_match "Nova lozinka", mail.subject
    assert_match %r{http://demo\.localhost/password_resets/[^/]+/edit}, mail.text_part.body.to_s
  end

  test "invitation links to the invitation page" do
    mail = UserMailer.with(user: users(:demo_imam), inviter: users(:demo_owner), locale: "en").invitation
    assert_match "Invitation to Demo Džemat", mail.subject
    assert_match %r{http://demo\.localhost/invitation/}, mail.text_part.body.to_s
    assert_match "Emir Demo", mail.text_part.body.to_s
  end
end
