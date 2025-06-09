# frozen_string_literal: true

require_relative "../../test_helper"

class EntraId::AuthorizationTest < ActiveSupport::TestCase
  include OauthTestHelper

  setup do
    Setting.plugin_entra_id = {
      enabled: true,
      client_id: "test-client-id",
      client_secret: "test-client-secret",
      tenant_id: "test-tenant-id"
    }.with_indifferent_access

    @redirect_uri = "https://example.com/callback"
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

  test "generates a random values when not provided" do
    auth1 = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    auth2 = EntraId::Authorization.new(redirect_uri: @redirect_uri)

    assert_not_equal auth1.code_verifier, auth2.code_verifier
    assert_not_equal auth1.state, auth2.state
    assert_not_equal auth1.nonce, auth2.nonce
  end

  test "code_challenge generates a SHA256 hash" do
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
    assert_equal "/#{EntraId.tenant_id}/oauth2/v2.0/authorize", parsed_url.path

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
    id_token = create_valid_jwt_token(authorization.nonce)
    
    stub_token_exchange("auth-code", id_token, authorization.code_verifier, redirect_uri: @redirect_uri)
    stub_jwks_endpoint

    identity = authorization.exchange_code_for_identity(code: "auth-code")

    assert_instance_of EntraId::Identity, identity
  end

  test "exchange_code_for_identity returns nil with invalid nonce" do
    authorization = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    id_token = create_valid_jwt_token("wrong-nonce")
    
    stub_token_exchange("auth-code", id_token, authorization.code_verifier, redirect_uri: @redirect_uri)
    stub_jwks_endpoint

    identity = authorization.exchange_code_for_identity(code: "auth-code")

    assert_nil identity
  end

  test "exchange_code_for_identity returns nil with JWT verification error" do
    authorization = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    invalid_token = create_invalid_jwt_token
    
    stub_token_exchange("auth-code", invalid_token, authorization.code_verifier, redirect_uri: @redirect_uri)
    stub_jwks_endpoint

    identity = authorization.exchange_code_for_identity(code: "auth-code")

    assert_nil identity
  end
end
