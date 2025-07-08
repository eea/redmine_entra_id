# frozen_string_literal: true

require_relative "../../test_helper"

class EntraId::CallbacksControllerTest < Redmine::IntegrationTest
  include OauthTestHelper

  setup do
    Setting.plugin_entra_id = {
      "enabled" => true
    }.with_indifferent_access
  end

  test "user data gets synced from EntraId on login" do
    user = users(:users_002)
    user.update!(oid: "test-oid-123", firstname: "OldFirstName", lastname: "OldLastName")

    get new_entra_id_authorization_path
    assert_redirected_to %r{https://login\.microsoftonline\.com}

    state = session[:entra_id_state]
    code_verifier = session[:entra_id_pkce_verifier]
    nonce = session[:entra_id_nonce]
    authorization_code = "test-code"

    stub_full_oauth_flow(
      code: authorization_code,
      code_verifier: code_verifier,
      nonce: nonce,
      user_data: {
        id: "test-oid-123",
        givenName: "NewFirstName",
        surname: "NewLastName",
        mail: user.mail
      }
    )

    get entra_id_callback_path, params: { code: authorization_code, state: state }

    assert_redirected_to my_page_path

    user.reload
    assert_equal "NewFirstName", user.firstname
    assert_equal "NewLastName", user.lastname
    assert_equal "test-oid-123", user.oid
    assert_not_nil user.synced_at
  end

  test "OAuth error in params redirects to signin with error message" do
    get entra_id_callback_path, params: {
      error: "access_denied",
      error_description: "The user denied the request"
    }

    assert_redirected_to signin_path
    assert_equal "The user denied the request", flash[:error]
  end

  test "missing state parameter shows invalid OAuth credentials error" do
    get entra_id_callback_path, params: {
      code: "test-code"
    }

    assert_redirected_to signin_path
    assert_equal "Invalid OAuth credentials. Authentication failed", flash[:error]
  end

  test "missing state in session shows invalid OAuth credentials error" do
    get entra_id_callback_path, params: { code: "test-code", state: "random-state" }

    assert_redirected_to signin_path
    assert_equal "Invalid OAuth credentials. Authentication failed", flash[:error]
  end

  test "state mismatch redirects to signin with invalid OAuth state error" do
    get new_entra_id_authorization_path
    
    get entra_id_callback_path, params: { 
      code: "test-code", 
      state: "different-state" 
    }

    assert_redirected_to signin_path
    assert_equal "Invalid OAuth state. Authentication failed", flash[:error]
  end

  test "OAuth2 error during token exchange redirects to signin with invalid token error" do
    get new_entra_id_authorization_path
    state = session[:entra_id_state]

    token_endpoint = "https://login.microsoftonline.com/test-tenant-id/oauth2/v2.0/token"
    stub_request(:post, token_endpoint)
      .to_return(status: 400, body: { error: "invalid_grant" }.to_json)

    get entra_id_callback_path, params: { code: "invalid-code", state: state }

    assert_redirected_to signin_path
    assert_equal "Invalid OAuth token. Authentication failed.", flash[:error]
  end

  test "inactive user gets account disabled error" do
    user = users(:users_002)
    user.update!(oid: "test-oid-123", status: User::STATUS_LOCKED)

    get new_entra_id_authorization_path
    state = session[:entra_id_state]
    code_verifier = session[:entra_id_pkce_verifier]
    nonce = session[:entra_id_nonce]
    authorization_code = "test-code"

    stub_full_oauth_flow(
      code: authorization_code,
      code_verifier: code_verifier,
      nonce: nonce,
      user_data: {
        id: "test-oid-123",
        givenName: "NewFirstName",
        surname: "NewLastName",
        mail: user.mail
      }
    )

    get entra_id_callback_path, params: { code: authorization_code, state: state }

    assert_redirected_to signin_path
    assert_equal "Your account is locked.", flash[:error]
  end

  test "new user with self-registration enabled creates and activates user" do
    with_settings self_registration: "3" do
      get new_entra_id_authorization_path
      state = session[:entra_id_state]
      code_verifier = session[:entra_id_pkce_verifier]
      nonce = session[:entra_id_nonce]
      authorization_code = "test-code"

      stub_full_oauth_flow(
        code: authorization_code,
        code_verifier: code_verifier,
        nonce: nonce,
        user_data: {
          id: "new-user-oid-456",
          givenName: "NewUser",
          surname: "LastName",
          mail: "newuser#{Time.now.to_f}@example.com"
        }
      )

      assert_difference "User.count", 1 do
        get entra_id_callback_path, params: {
          code: authorization_code,
          state: state
        }
      end

      assert_redirected_to my_account_path

      new_user = User.find_by(oid: "new-user-oid-456")

      assert_not_nil new_user
      assert_equal "new-user-oid-456", new_user.oid
      assert_equal "NewUser", new_user.firstname
      assert_equal "LastName", new_user.lastname
      assert new_user.active?
      assert_nil new_user.auth_source_id
    end
  end

  test "callback returns 400 when EntraId is disabled" do
    Setting.plugin_entra_id = { "enabled" => false }

    get entra_id_callback_path, params: {
      code: "test-code",
      state: "test-state"
    }

    assert_response :bad_request
  end

  test "successful authentication clears OAuth session data" do
    user = users(:users_002)
    user.update!(oid: "test-oid-123")

    get new_entra_id_authorization_path

    assert_redirected_to %r{https://login\.microsoftonline\.com}
    assert_not_nil session[:entra_id_state]
    assert_not_nil session[:entra_id_nonce]
    assert_not_nil session[:entra_id_pkce_verifier]

    state = session[:entra_id_state]
    code_verifier = session[:entra_id_pkce_verifier]
    nonce = session[:entra_id_nonce]
    authorization_code = "test-code"

    stub_full_oauth_flow(
      code: authorization_code,
      code_verifier: code_verifier,
      nonce: nonce,
      user_data: {
        id: "test-oid-123",
        givenName: "TestFirst",
        surname: "TestLast",
        mail: user.mail
      }
    )

    get entra_id_callback_path, params: {
      code: authorization_code,
      state: state
    }

    assert_redirected_to my_page_path

    assert_nil session[:entra_id_state]
    assert_nil session[:entra_id_nonce]
    assert_nil session[:entra_id_pkce_verifier]
  end

  test "existing user with auth_source gets auth_source cleared on EntraId login" do
    user = users(:users_002)
    user.update!(oid: "test-oid-123", auth_source_id: 1)
    
    get new_entra_id_authorization_path
    assert_redirected_to %r{https://login\.microsoftonline\.com}

    state = session[:entra_id_state]
    code_verifier = session[:entra_id_pkce_verifier]
    nonce = session[:entra_id_nonce]
    authorization_code = "test-code"

    stub_full_oauth_flow(
      code: authorization_code,
      code_verifier: code_verifier,
      nonce: nonce,
      user_data: {
        id: "test-oid-123",
        givenName: "TestFirst",
        surname: "TestLast",
        mail: user.mail
      }
    )

    get entra_id_callback_path, params: { code: authorization_code, state: state }

    assert_redirected_to my_page_path

    user.reload
    assert_nil user.auth_source_id
  end

  test "failed authentication due to OAuth error clears OAuth session data" do
    get new_entra_id_authorization_path
    
    assert_not_nil session[:entra_id_state]
    assert_not_nil session[:entra_id_nonce]
    assert_not_nil session[:entra_id_pkce_verifier]

    get entra_id_callback_path, params: {
      error: "access_denied",
      error_description: "The user denied the request"
    }

    assert_redirected_to signin_path
    assert_equal "The user denied the request", flash[:error]

    assert_nil session[:entra_id_state]
    assert_nil session[:entra_id_nonce]
    assert_nil session[:entra_id_pkce_verifier]
  end

  test "failed authentication due to state mismatch clears OAuth session data" do
    get new_entra_id_authorization_path
    
    assert_not_nil session[:entra_id_state]
    assert_not_nil session[:entra_id_nonce]
    assert_not_nil session[:entra_id_pkce_verifier]
    
    get entra_id_callback_path, params: {  code: "test-code", state: "different-state" }

    assert_redirected_to signin_path
    assert_equal "Invalid OAuth state. Authentication failed", flash[:error]

    assert_nil session[:entra_id_state]
    assert_nil session[:entra_id_nonce]
    assert_nil session[:entra_id_pkce_verifier]
  end
end
