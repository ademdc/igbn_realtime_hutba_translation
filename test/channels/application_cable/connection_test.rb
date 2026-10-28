require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    test "connects and identifies account by host" do
      connect headers: { "HOST" => "demo.localhost" }
      assert_equal accounts(:demo), connection.account
      assert_not connection.speaker?
    end

    test "signed-in mosque user counts as speaker" do
      user = users(:demo_imam)
      cookies.encrypted[Rails.application.config.session_options[:key]] =
        { "user_id" => user.id, "user_fingerprint" => user.session_fingerprint }
      connect headers: { "HOST" => "demo.localhost" }
      assert connection.speaker?
    end

    test "user of another mosque is not a speaker" do
      user = users(:igbd_owner)
      cookies.encrypted[Rails.application.config.session_options[:key]] =
        { "user_id" => user.id, "user_fingerprint" => user.session_fingerprint }
      connect headers: { "HOST" => "demo.localhost" }
      assert_not connection.speaker?
    end

    test "rejects unknown host" do
      assert_reject_connection { connect headers: { "HOST" => "nope.localhost" } }
    end
  end
end
