# frozen_string_literal: true

require_relative "../test_helper"

class EntraIdTest < ActiveSupport::TestCase
  setup do
    Setting.plugin_entra_id = {
      enabled: true,
      exclusive: false
    }
  end


  test "client_secret returns nil when environment variable is not set" do
    ENV.delete("ENTRA_ID_CLIENT_SECRET")
    
    assert_nil EntraId.client_secret
  end





  test "masked_client_secret shows first 3 characters with asterisks" do
    ENV["ENTRA_ID_CLIENT_SECRET"] = "secret123456789"
    
    assert_equal "sec******************", EntraId.masked_client_secret
  end


  test "masked_client_secret returns empty string for blank secrets" do
    ENV.delete("ENTRA_ID_CLIENT_SECRET")
    
    assert_equal "", EntraId.masked_client_secret
  end

  test "valid when fully configured" do
    # Environment variables are already set in setup
    assert EntraId.valid?
  end

  test "invalid when disabled" do
    Setting.plugin_entra_id = Setting.plugin_entra_id.merge(enabled: false)
    
    assert_not EntraId.valid?
  end

  test "invalid without client_id" do
    ENV.delete("ENTRA_ID_CLIENT_ID")
    
    assert_not EntraId.valid?
  end

  test "invalid without client_secret" do
    ENV.delete("ENTRA_ID_CLIENT_SECRET")
    
    assert_not EntraId.valid?
  end

  test "invalid without tenant_id" do
    ENV.delete("ENTRA_ID_TENANT_ID")
    
    assert_not EntraId.valid?
  end

  test "client_id reads from environment variable" do
    ENV["ENTRA_ID_CLIENT_ID"] = "env-client-id"
    
    assert_equal "env-client-id", EntraId.client_id
  end

  test "client_secret reads from environment variable" do
    ENV["ENTRA_ID_CLIENT_SECRET"] = "env-client-secret"
    
    assert_equal "env-client-secret", EntraId.client_secret
  end

  test "tenant_id reads from environment variable" do
    ENV["ENTRA_ID_TENANT_ID"] = "env-tenant-id"
    
    assert_equal "env-tenant-id", EntraId.tenant_id
  end
end
