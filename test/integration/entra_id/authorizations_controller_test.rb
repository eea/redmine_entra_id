# frozen_string_literal: true

require_relative "../../test_helper"

class EntraId::AuthorizationsControllerTest < Redmine::IntegrationTest
  def test_clicking_entra_id_button_initiates_oauth_flow
    with_settings plugin_entra_id: {
      enabled: true,
      client_id: "test-client-id",
      tenant_id: "test-tenant-id"
    } do
      get new_entra_id_authorization_path

      assert_response :redirect

      # Should redirect to Microsoft authorization endpoint
      assert_match(/login\.microsoftonline\.com/, response.location)
      assert_match(/oauth2\/v2\.0\/authorize/, response.location)

      # Should contain required OAuth parameters
      assert_match(/client_id=test-client-id/, response.location)
      assert_match(/scope=openid%20profile%20email/, response.location)
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
  end
end
