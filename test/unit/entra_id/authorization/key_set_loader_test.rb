# frozen_string_literal: true

require_relative "../../../test_helper"

class EntraId::Authorization::KeySetLoaderTest < ActiveSupport::TestCase
  setup do
    Setting.plugin_entra_id = {
      enabled: true,
      client_id: "test-client-id",
      client_secret: "test-client-secret",
      tenant_id: "test-tenant-id"
    }.with_indifferent_access
    
    @endpoint = "https://login.microsoftonline.com/test-tenant-id/discovery/v2.0/keys"
    
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end
  
  teardown do
    Rails.cache = @original_cache_store
  end
  
  test "call fetches JWKS from Microsoft and returns expected keys" do
    stub_request(:get, @endpoint)
      .to_return(
        status: 200,
        body: file_fixture("jwks.json").read,
        headers: { "Content-Type" => "application/json" }
      )
    
    loader = EntraId::Authorization::KeySetLoader.new
    jwks = loader.call({})
    
    key_ids = jwks["keys"].map { |key| key["kid"] }
    assert_includes key_ids, "main-key-id"
    assert_includes key_ids, "backup-key-id"
    assert_not_includes key_ids, "invalid-key-id"
  end
  
  test "caching respects HTTP Cache-Control max-age header" do
    stub_request(:get, @endpoint)
      .to_return(
        status: 200,
        body: file_fixture("jwks.json").read,
        headers: { 
          "Content-Type" => "application/json",
          "Cache-Control" => "max-age=300"
        }
      )
    
    loader = EntraId::Authorization::KeySetLoader.new
    
    loader.call({})
    assert_requested :get, @endpoint, times: 1
    
    travel_to 4.minutes.from_now do
      loader.call({})
      assert_requested :get, @endpoint, times: 1 # Should still be 1, not 2
    end
    
    travel_to 6.minutes.from_now do
      loader.call({})
      assert_requested :get, @endpoint, times: 2 # Should now be 2
    end
  end
  
  test "call with kid_not_found option forces refresh even with valid cache" do
    stub_request(:get, @endpoint)
      .to_return(
        status: 200,
        body: file_fixture("jwks.json").read,
        headers: { 
          "Content-Type" => "application/json",
          "Cache-Control" => "max-age=3600" # 1 hour
        }
      )
    
    loader = EntraId::Authorization::KeySetLoader.new
    
    loader.call({})
    assert_requested :get, @endpoint, times: 1
    
    loader.call({ kid_not_found: true })
    assert_requested :get, @endpoint, times: 2
  end
end