# frozen_string_literal: true

require_relative "../../test_helper"

class EntraId::AuthorizationTest < ActiveSupport::TestCase
  include Redmine::I18n
  def setup
    @original_settings = Setting.plugin_entra_id.dup
    Setting.plugin_entra_id = {
      enabled: true,
      client_id: "test-client-id",
      client_secret: "test-client-secret",
      tenant_id: "test-tenant-id"
    }

    @redirect_uri = "https://example.com/callback"
  end

  def teardown
    Setting.plugin_entra_id = @original_settings
  end

  test "initializes with required redirect_uri" do
    auth = EntraId::Authorization.new(redirect_uri: @redirect_uri)

    assert_equal @redirect_uri, auth.redirect_uri
    assert auth.code_verifier.present?
    assert auth.state.present?
    assert auth.nonce.present?
  end

  test "initializes with custom parameters" do
    code_verifier = "custom-verifier"
    state = "custom-state"
    nonce = "custom-nonce"

    auth = EntraId::Authorization.new(
      redirect_uri: @redirect_uri,
      code_verifier: code_verifier,
      state: state,
      nonce: nonce
    )

    assert_equal @redirect_uri, auth.redirect_uri
    assert_equal code_verifier, auth.code_verifier
    assert_equal state, auth.state
    assert_equal nonce, auth.nonce
  end

  test "generates secure random values when not provided" do
    auth1 = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    auth2 = EntraId::Authorization.new(redirect_uri: @redirect_uri)

    assert_not_equal auth1.code_verifier, auth2.code_verifier
    assert_not_equal auth1.state, auth2.state
    assert_not_equal auth1.nonce, auth2.nonce
  end

  test "code_challenge generates correct SHA256 hash" do
    code_verifier = "test-verifier"
    auth = EntraId::Authorization.new(
      redirect_uri: @redirect_uri,
      code_verifier: code_verifier
    )

    expected_challenge = Base64.urlsafe_encode64(
      Digest::SHA256.digest(code_verifier),
      padding: false
    )

    assert_equal expected_challenge, auth.code_challenge
  end

  test "url generates correct authorization URL" do
    authorization = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    url = authorization.url

    parsed_url = URI.parse(url)
    params = CGI.parse(parsed_url.query)

    assert_equal "https", parsed_url.scheme
    assert_equal "login.microsoftonline.com", parsed_url.host
    assert_equal "/test-tenant-id/oauth2/v2.0/authorize", parsed_url.path

    assert_equal [ "test-client-id" ], params["client_id"]
    assert_equal [ @redirect_uri ], params["redirect_uri"]
    assert_equal [ "openid profile email" ], params["scope"]
    assert_equal [ "code" ], params["response_type"]
    assert_equal [ "query" ], params["response_mode"]
    assert_equal [ authorization.state ], params["state"]
    assert_equal [ authorization.nonce ], params["nonce"]
    assert_equal [ authorization.code_challenge ], params["code_challenge"]
    assert_equal [ "S256" ], params["code_challenge_method"]
    assert_equal [ "select_account" ], params["prompt"]
  end

  test "exchange_code_for_identity returns identity with valid token" do
    authorization = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    mock_access_token = mock_access_token_response(authorization, "mock.jwt.token")
    mock_jwt_verification(authorization)

    authorization.send(:client).auth_code.stubs(:get_token)
      .with("auth-code", { redirect_uri: @redirect_uri, code_verifier: authorization.code_verifier })
      .returns(mock_access_token)

    identity = authorization.exchange_code_for_identity(code: "auth-code")

    assert_instance_of EntraId::Identity, identity
  end

  test "exchange_code_for_identity returns nil with invalid nonce" do
    authorization = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    mock_access_token = mock_access_token_response(authorization, "mock.jwt.token")
    mock_jwt_verification(authorization, nonce: "wrong-nonce")

    authorization.send(:client).auth_code.stubs(:get_token)
      .returns(mock_access_token)

    identity = authorization.exchange_code_for_identity(code: "auth-code")

    assert_nil identity
  end

  test "exchange_code_for_identity returns nil with JWT verification error" do
    authorization = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    mock_access_token = mock_access_token_response(authorization, "mock.jwt.token")
    mock_jwt_verification(authorization, should_succeed: false)

    authorization.send(:client).auth_code.stubs(:get_token)
    .returns(mock_access_token)

    identity = authorization.exchange_code_for_identity(code: "auth-code")

    assert_nil identity
  end



  private

    def mock_access_token_response(authorization, jwt_token)
      mock_token = stub("access_token")
      mock_token.stubs(:params).returns({ "id_token" => jwt_token })
      mock_token.stubs(:token).returns("access_token_value")
      mock_token
    end

    def mock_jwt_verification(authorization, nonce: nil, should_succeed: true)
      if should_succeed
        # Mock successful JWT verification
        claims = {
          "oid" => "user-id",
          "preferred_username" => "test@example.com",
          "nonce" => nonce || authorization.nonce
      }

      authorization.stubs(:decode_id_token).returns(claims)
      else
        # Mock failed JWT verification
        authorization.stubs(:decode_id_token).raises(JWT::VerificationError.new("Mock verification error"))
      end
    end
end
