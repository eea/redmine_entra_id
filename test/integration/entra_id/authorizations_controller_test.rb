# frozen_string_literal: true

require_relative "../../test_helper"

class EntraId::AuthorizationsControllerTest < ActionDispatch::IntegrationTest
  test "clicking entra_id button initiates oauth flow" do
    Setting.plugin_entra_id = {
      enabled: true,
      client_id: "test-client-id",
      client_secret: EntraId.encrypt_client_secret("test-secret-123"),
      tenant_id: "test-tenant-id"
    }
    
    get new_entra_id_authorization_path

    assert_response :redirect

    # Should redirect to Microsoft authorization endpoint
    assert_match(/login\.microsoftonline\.com/, response.location)
    assert_match(/oauth2\/v2\.0\/authorize/, response.location)

    # Should contain required OAuth parameters
    assert_match(/client_id=test-client-id/, response.location)
    assert_match(/response_type=code/, response.location)
    assert_match(/code_challenge=/, response.location)
    assert_match(/code_challenge_method=S256/, response.location)
    assert_match(/state=/, response.location)
    assert_match(/nonce=/, response.location)

    # Should store security values in session
    assert session[:entra_id_state].present?
    assert session[:entra_id_nonce].present?
    assert session[:entra_id_pkce_verifier].present?
  end

  test "redirects to login when plugin is disabled" do
    Setting.plugin_entra_id = {
      enabled: false,
      client_id: "test-client-id",
      client_secret: EntraId.encrypt_client_secret("test-secret-123"),
      tenant_id: "test-tenant-id"
    }

    get new_entra_id_authorization_path

    assert_redirected_to signin_path
    assert_equal "EntraId authentication is not properly configured.", flash[:error]
  end

  test "redirects to login when client_secret is missing" do
    Setting.plugin_entra_id = {
      enabled: true,
      client_id: "test-client-id",
      client_secret: nil,
      tenant_id: "test-tenant-id"
    }

    get new_entra_id_authorization_path

    assert_redirected_to signin_path
    assert_equal "EntraId authentication is not properly configured.", flash[:error]
  end
end
