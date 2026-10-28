require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    test "connects and identifies account by host" do
      connect headers: { "HOST" => "demo.localhost" }
      assert_equal accounts(:demo), connection.account
      assert_not connection.speaker?
    end

    test "rejects unknown host" do
      assert_reject_connection { connect headers: { "HOST" => "nope.localhost" } }
    end
  end
end
