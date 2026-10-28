require "test_helper"

class TeamTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    host! "demo.localhost"
    post "/login", params: { email: "owner@demo.test", password: "password1234" }
  end

  test "owner invites a speaker who then sets a password" do
    assert_enqueued_emails 1 do
      post "/dashboard/team", params: { user: { name: "Hafiz", email: "hafiz@demo.test", role: "speaker" } }
    end
    assert_redirected_to "http://demo.localhost/dashboard/team"

    invited = accounts(:demo).users.find_by!(email: "hafiz@demo.test")
    assert invited.invitation_pending?

    delete "/logout"
    token = invited.generate_token_for(:invitation)
    get "/invitation/#{token}"
    assert_response :success

    patch "/invitation/#{token}", params: { user: { password: "hafizpassword", password_confirmation: "hafizpassword" } }
    assert_redirected_to "http://demo.localhost/"
    assert_not invited.reload.invitation_pending?
  end

  test "invalid invitation shows errors" do
    post "/dashboard/team", params: { user: { name: "", email: "bad", role: "speaker" } }
    assert_response :unprocessable_entity
    assert_select ".errors"
  end

  test "owner removes a team member but not themselves" do
    delete "/dashboard/team/#{users(:demo_imam).id}"
    assert_not User.exists?(users(:demo_imam).id)

    delete "/dashboard/team/#{users(:demo_owner).id}"
    assert User.exists?(users(:demo_owner).id)
  end

  test "owner cannot remove users of another mosque" do
    delete "/dashboard/team/#{users(:igbd_owner).id}"
    assert_response :not_found
    assert User.exists?(users(:igbd_owner).id)
  end
end
