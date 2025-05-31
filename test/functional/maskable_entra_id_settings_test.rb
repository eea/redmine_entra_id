# frozen_string_literal: true

require "test_helper"

class MaskableEntraIdSettingsTest < ActionController::TestCase
  tests SettingsController

  def setup
    super
    @user = User.find(1)
    User.current = @user
    @request.session[:user_id] = @user.id

    @original_settings = Setting.plugin_entra_id.dup
    # Set up initial settings with an encrypted secret
    @test_secret = "original-secret-123"
    encrypted_secret = EntraId.encrypt_client_secret(@test_secret)
    Setting.plugin_entra_id = {
      enabled: true,
      exclusive: false,
      client_id: "test-client-id",
      client_secret: encrypted_secret,
      tenant_id: "test-tenant-id"
    }
  end

  def teardown
    Setting.plugin_entra_id = @original_settings
  end

  test "preserves encrypted secret when masked value is submitted" do
    masked_secret = EntraId.masked_client_secret
    original_encrypted = EntraId.raw_client_secret

    post :plugin, params: {
      id: "entra_id",
      settings: {
        enabled: true,
        client_id: "new-client-id",
        client_secret: masked_secret,
        tenant_id: "new-tenant-id"
      }
    }

    assert_response :redirect
    # Verify that the original secret is preserved
    assert_equal original_encrypted, Setting.plugin_entra_id["client_secret"]
  end

  test "encrypts new secret when different value is submitted" do
    new_secret = "brand-new-secret-456"

    post :plugin, params: {
      id: "entra_id",
      settings: {
        enabled: true,
        client_id: "new-client-id",
        client_secret: new_secret,
        tenant_id: "new-tenant-id"
      }
    }

    assert_response :redirect

    # Should be encrypted (not the plain value)
    encrypted_value = Setting.plugin_entra_id["client_secret"]
    assert_not_equal new_secret, encrypted_value
    assert encrypted_value.present?

    # When we read it back through the module, should get the original
    assert_equal new_secret, EntraId.client_secret
  end

  test "handles empty secret submission" do
    post :plugin, params: {
      id: "entra_id",
      settings: {
        enabled: true,
        client_id: "new-client-id",
        client_secret: "",
        tenant_id: "new-tenant-id"
      }
    }

    assert_response :redirect
    # Should preserve empty value
    assert_equal "", Setting.plugin_entra_id["client_secret"]
  end

  test "handles nil secret submission" do
    post :plugin, params: {
      id: "entra_id",
      settings: {
        enabled: true,
        client_id: "new-client-id",
        tenant_id: "new-tenant-id"
      }
    }

    assert_response :redirect
    # Should not have client_secret key when nil
    assert_nil Setting.plugin_entra_id["client_secret"]
  end

  test "round trip with masked secret preserves decryption" do
    # Simulate the typical UI workflow
    masked_secret = EntraId.masked_client_secret
    original_decrypted = EntraId.client_secret

    # Submit the form with masked secret (user didn't change it)
    post :plugin, params: {
      id: "entra_id",
      settings: {
        enabled: false, # Changed this setting
        client_secret: masked_secret # But kept secret as masked
      }
    }

    assert_response :redirect

    # Secret should still decrypt to the same value
    assert_equal original_decrypted, EntraId.client_secret
    assert_equal "false", EntraId.enabled?.to_s # Other setting should be updated
  end

  test "updates client_id setting" do
    new_client_id = "new-client-id-123"

    post :plugin, params: {
      id: "entra_id",
      settings: {
        client_id: new_client_id,
        client_secret: EntraId.masked_client_secret
      }
    }

    assert_response :redirect
    assert_equal new_client_id, Setting.plugin_entra_id["client_id"]
    assert_equal new_client_id, EntraId.client_id
  end

  test "updates tenant_id setting" do
    new_tenant_id = "new-tenant-id-456"

    post :plugin, params: {
      id: "entra_id",
      settings: {
        tenant_id: new_tenant_id,
        client_secret: EntraId.masked_client_secret
      }
    }

    assert_response :redirect
    assert_equal new_tenant_id, Setting.plugin_entra_id["tenant_id"]
    assert_equal new_tenant_id, EntraId.tenant_id
  end

  test "handles empty client_id" do
    post :plugin, params: {
      id: "entra_id",
      settings: {
        client_id: "",
        client_secret: EntraId.masked_client_secret
      }
    }

    assert_response :redirect
    assert_equal "", Setting.plugin_entra_id["client_id"]
  end

  test "handles empty tenant_id" do
    post :plugin, params: {
      id: "entra_id",
      settings: {
        tenant_id: "",
        client_secret: EntraId.masked_client_secret
      }
    }

    assert_response :redirect
    assert_equal "", Setting.plugin_entra_id["tenant_id"]
  end
end
