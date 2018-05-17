require_relative "../../spec_helper"

if ActiveSupport.version >= Gem::Version.new("5.2.0")
  describe "RedisCacheStore as a cache backend" do
    before do
      Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new
    end

    after do
      Rack::Attack.cache.store.clear
    end

    it "works for throttle" do
      Rack::Attack.throttle("by ip", limit: 1, period: 60) do |request|
        request.ip
      end

      get "/", {}, "REMOTE_ADDR" => "1.2.3.4"

      assert_equal 200, last_response.status

      get "/", {}, "REMOTE_ADDR" => "1.2.3.4"

      assert_equal 429, last_response.status
    end

    it "works for fail2ban" do
      Rack::Attack.blocklist("fail2ban pentesters") do |request|
        Rack::Attack::Fail2Ban.filter(request.ip, maxretry: 2, findtime: 30, bantime: 60) do
          request.path.include?("private-place")
        end
      end

      get "/"
      assert_equal 200, last_response.status

      get "/private-place"
      assert_equal 403, last_response.status

      get "/private-place"
      assert_equal 403, last_response.status

      get "/"
      assert_equal 403, last_response.status
    end

    it "works for allow2ban" do
      Rack::Attack.blocklist("allow2ban pentesters") do |request|
        Rack::Attack::Allow2Ban.filter(request.ip, maxretry: 2, findtime: 30, bantime: 60) do
          request.path.include?("scarce-resource")
        end
      end

      get "/"
      assert_equal 200, last_response.status

      get "/scarce-resource"
      assert_equal 200, last_response.status

      get "/scarce-resource"
      assert_equal 200, last_response.status

      get "/scarce-resource"
      assert_equal 403, last_response.status

      get "/"
      assert_equal 403, last_response.status
    end
  end
end
