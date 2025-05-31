# frozen_string_literal: true

require "test_helper"

class LoginPageTest < Redmine::IntegrationTest
  def test_plugin_disabled_no_entra_id_button_appears
    with_settings plugin_entra_id: { enabled: false } do
      get signin_path

      assert_response :success
      assert_select "#entra-id-form", count: 0
      assert_select "a", text: "Login with EntraID", count: 0
      assert_select "#login-form", count: 1
      assert_select "input#username", count: 1
      assert_select "input#password", count: 1
    end
  end

  def test_plugin_enabled_entra_id_button_and_regular_form_appear
    with_settings plugin_entra_id: { enabled: true, exclusive: false } do
      get signin_path

      assert_response :success
      assert_select "#entra-id-form", count: 1
      assert_select "a", text: "Login with EntraID", count: 1
      assert_select "#login-form", count: 1
      assert_select "input#username", count: 1
      assert_select "input#password", count: 1
    end
  end

  def test_plugin_enabled_and_exclusive_only_entra_id_button_appears
    with_settings plugin_entra_id: { enabled: true, exclusive: true } do
      get signin_path

      assert_response :success
      assert_select "#entra-id-form", count: 1
      assert_select "a", text: "Login with EntraID", count: 1
      assert_select "#login-form", count: 0
      assert_select "input#username", count: 0
      assert_select "input#password", count: 0
    end
  end

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
      assert_match(/scope=openid\+profile\+email/, response.location)
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
