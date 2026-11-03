require "test_helper"

class CustomDomains::FlyClientTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :body, :success) do
    def is_a?(klass) = klass == Net::HTTPSuccess ? success : super
  end

  setup do
    @env = ENV.to_h.slice("FLY_API_TOKEN", "FLY_APP_NAME")
    ENV["FLY_API_TOKEN"] = "FlyV1 fm2_test"
    ENV["FLY_APP_NAME"] = "hutba"
    @client = CustomDomains::FlyClient.new
    @requests = []
  end

  teardown do
    %w[FLY_API_TOKEN FLY_APP_NAME].each { |key| ENV[key] = @env[key] }
  end

  test "add requests an ACME certificate and returns the CNAME target" do
    stub_http(Response.new("200", { hostname: "hutba.mosque.com", status: "Awaiting configuration",
                                    dns_requirements: { cname: "hutba.fly.dev" }, certificates: [] }.to_json, true)) do
      domain = @client.add("hutba.mosque.com")
      assert_equal "hutba.fly.dev", domain.target
      refute domain.certificate_issued?
    end

    req = @requests.first
    assert_kind_of Net::HTTP::Post, req
    assert_equal "/v1/apps/hutba/certificates/acme", req.path
    assert_equal "FlyV1 fm2_test", req["Authorization"]
    assert_equal({ "hostname" => "hutba.mosque.com" }, JSON.parse(req.body))
  end

  test "info reports an issued certificate" do
    body = { hostname: "hutba.mosque.com", certificates: [{ source: "fly", status: "active" }] }.to_json
    stub_http(Response.new("200", body, true)) do
      assert @client.info("hutba.mosque.com").certificate_issued?
    end
    assert_equal "/v1/apps/hutba/certificates/hutba.mosque.com/check", @requests.first.path
  end

  test "remove ignores hostnames Fly doesn't know" do
    stub_http(Response.new("404", { error: "not found" }.to_json, false)) do
      assert_nothing_raised { @client.remove("old.mosque.com") }
    end
  end

  test "errors are CustomDomains errors" do
    stub_http(Response.new("401", { error: "unauthorized" }.to_json, false)) do
      assert_raises(CustomDomains::Error) { @client.info("hutba.mosque.com") }
    end
  end

  private

  def stub_http(response)
    requests = @requests
    @client.define_singleton_method(:perform) { |_uri, req| requests << req; response }
    yield
  end
end
