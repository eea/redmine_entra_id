# frozen_string_literal: true

require_relative "../test_helper"

class SettingsControllerTest < Redmine::IntegrationTest
  setup do
    Setting.plugin_entra_id = {
      "enabled" => true,
      "client_id" => "test-client-id",
      "client_secret" => EntraId.encrypt_client_secret("test-secret"),
      "tenant_id" => "test-tenant-id"
    }.with_indifferent_access
  end

  test "unauthenticated user cannot access plugin settings page" do
    get plugin_settings_path("entra_id")

    assert_response :redirect
    assert_match %r{/login}, response.location
  end

  test "regular user cannot access plugin settings page" do
    log_user("jsmith", "jsmith")

    get plugin_settings_path("entra_id")

    assert_response :forbidden
  end

  test "only admin user can access plugin settings page" do
    log_user("admin", "admin")

    get plugin_settings_path("entra_id")

    assert_response :success
    assert_select "form[action*='plugin']"
  end

  test "unauthenticated user cannot update plugin settings" do
    post plugin_settings_path("entra_id"), params: {
      settings: {
        enabled: false,
        client_id: "unauthenticated-attempt"
      }
    }

    assert_response :redirect
    assert_match %r{/login}, response.location
    # Settings should remain unchanged
    assert_equal "test-client-id", Setting.plugin_entra_id["client_id"]
  end

  test "regular user cannot update plugin settings" do
    log_user("jsmith", "jsmith")

    post plugin_settings_path("entra_id"), params: {
      settings: {
        enabled: false,
        client_id: "hacker-attempt"
      }
    }

    assert_response :forbidden
    assert_equal "test-client-id", Setting.plugin_entra_id["client_id"]
  end

  test "admin user can update plugin settings" do
    log_user("admin", "admin")

    post plugin_settings_path("entra_id"), params: {
      settings: {
        client_id: "updated-client-id"
      }
    }

    assert_response :redirect
    assert_equal "updated-client-id", Setting.plugin_entra_id["client_id"]
  end

  test "preserves encrypted secret when masked value is submitted" do
    log_user("admin", "admin")

    masked_secret = EntraId.masked_client_secret
    original_encrypted = EntraId.raw_client_secret

    post plugin_settings_path("entra_id"), params: {
      settings: {
        enabled: true,
        client_id: "new-client-id",
        client_secret: masked_secret,
        tenant_id: "new-tenant-id"
      }
    }

    assert_response :redirect
    # Verify that the original secret is preserved
    assert_equal original_encrypted, EntraId.raw_client_secret
  end

  test "encrypts new secret when different value is submitted" do
    log_user("admin", "admin")

    new_secret = "brand-new-secret-456"

    post plugin_settings_path("entra_id"), params: {
      settings: {
        enabled: true,
        client_id: "new-client-id",
        client_secret: new_secret,
        tenant_id: "new-tenant-id"
      }
    }

    assert_response :redirect
    assert_equal new_secret, EntraId.client_secret
  end

  test "handles empty secret submission" do
    log_user("admin", "admin")

    post plugin_settings_path("entra_id"), params: {
      settings: {
        enabled: true,
        client_id: "new-client-id",
        client_secret: "",
        tenant_id: "new-tenant-id"
      }
    }

    assert_response :redirect
    assert_equal "", EntraId.client_secret
  end

  test "handles nil secret submission" do
    log_user("admin", "admin")

    post plugin_settings_path("entra_id"), params: {
      settings: {
        enabled: true,
        client_id: "new-client-id",
        tenant_id: "new-tenant-id"
      }
    }

    assert_response :redirect
    assert_equal "", EntraId.client_secret
  end

  test "round trip with masked secret preserves decryption" do
    log_user("admin", "admin")

    new_client_id = "changed-client-id"
    new_tenant_id = "changed-tenant-id"

    masked_secret = EntraId.masked_client_secret
    original_decrypted = EntraId.client_secret

    post plugin_settings_path("entra_id"), params: {
      settings: {
        enabled: false,
        client_id: new_client_id,
        client_secret: masked_secret,
        tenant_id: new_tenant_id
      }
    }

    assert_response :redirect

    assert EntraId.enabled?

    assert_equal new_client_id, EntraId.client_id
    assert_equal original_decrypted, EntraId.client_secret
    assert_equal new_tenant_id, EntraId.tenant_id
  end

  test "handles empty client_id" do
    log_user("admin", "admin")

    post plugin_settings_path("entra_id"), params: {
      settings: { client_id: "", client_secret: EntraId.masked_client_secret }
    }

    assert_response :redirect
    assert_equal "", EntraId.client_id
  end

  test "handles empty tenant_id" do
    log_user("admin", "admin")

    post plugin_settings_path("entra_id"), params: {
      settings: { tenant_id: "", client_secret: EntraId.masked_client_secret }
    }

    assert_response :redirect
    assert_equal "", Setting.plugin_entra_id["tenant_id"]
  end
end
