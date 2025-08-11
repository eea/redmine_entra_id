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

  test "JWKS caching respects HTTP Cache-Control max-age header" do
    # Use memory store for this test since test environment uses null_store
    original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    
    # Clear cache before test
    Rails.cache.clear
    
    jwks_endpoint = "https://login.microsoftonline.com/test-tenant-id/discovery/v2.0/keys"

    rsa_key = test_rsa_key
    n = Base64.urlsafe_encode64(rsa_key.n.to_s(2), padding: false)
    e = Base64.urlsafe_encode64(rsa_key.e.to_s(2), padding: false)
    
    jwks_response = {
      keys: [ {
        kty: "RSA",
        use: "sig",
        kid: "test-key-id",
        n: n,
        e: e
      } ]
    }

    first_stub = stub_request(:get, jwks_endpoint)
      .to_return(
        status: 200,
        body: jwks_response.to_json,
        headers: { 
          "Content-Type" => "application/json",
          "Cache-Control" => "max-age=300"
        }
      )
    
    # First request should fetch JWKS
    authorization1 = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    id_token1 = create_valid_jwt_token(authorization1.nonce)
    stub_token_exchange("auth-code", id_token1, authorization1.code_verifier, redirect_uri: @redirect_uri)
    
    authorization1.exchange_code_for_identity(code: "auth-code")
    assert_requested first_stub, times: 1
    
    # Second request 4 minutes later - should still use cache
    authorization2 = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    id_token2 = create_valid_jwt_token(authorization2.nonce)
    stub_token_exchange("auth-code", id_token2, authorization2.code_verifier, redirect_uri: @redirect_uri)
    
    travel_to 4.minutes.from_now do
      authorization2.exchange_code_for_identity(code: "auth-code")
      assert_requested first_stub, times: 1 # Should still be 1, not 2
    end
    
    # Third request 6 minutes from start - cache should expire
    authorization3 = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    id_token3 = create_valid_jwt_token(authorization3.nonce)
    stub_token_exchange("auth-code", id_token3, authorization3.code_verifier, redirect_uri: @redirect_uri)
    
    travel_to 6.minutes.from_now do
      authorization3.exchange_code_for_identity(code: "auth-code")
      assert_requested first_stub, times: 2 # Should now be 2
    end
  ensure
    Rails.cache = original_cache_store
  end

  test "JWKS loader refreshes cache when kid not found" do
    # Use memory store for this test since test environment uses null_store
    original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    
    # Clear cache before test
    Rails.cache.clear
    
    jwks_endpoint = "https://login.microsoftonline.com/test-tenant-id/discovery/v2.0/keys"
    
    # Create RSA keys for testing
    rsa_key1 = test_rsa_key
    n1 = Base64.urlsafe_encode64(rsa_key1.n.to_s(2), padding: false)
    e1 = Base64.urlsafe_encode64(rsa_key1.e.to_s(2), padding: false)
    
    # Initial JWKS response with kid "test-key-id"
    initial_jwks = {
      keys: [ {
        kty: "RSA",
        use: "sig",
        kid: "test-key-id",
        n: n1,
        e: e1
      } ]
    }
    
    # Updated JWKS response with new kid "new-key-id"
    updated_jwks = {
      keys: [ 
        {
          kty: "RSA",
          use: "sig",
          kid: "test-key-id",
          n: n1,
          e: e1
        },
        {
          kty: "RSA",
          use: "sig",
          kid: "new-key-id",
          n: n1,
          e: e1
        }
      ]
    }
    
    # First stub returns initial JWKS
    initial_stub = stub_request(:get, jwks_endpoint)
      .to_return(
        status: 200,
        body: initial_jwks.to_json,
        headers: { 
          "Content-Type" => "application/json",
          "Cache-Control" => "max-age=3600" # 1 hour
        }
      ).times(1).then.to_return(
        status: 200,
        body: updated_jwks.to_json,
        headers: { 
          "Content-Type" => "application/json",
          "Cache-Control" => "max-age=3600"
        }
      )
    
    # First request with initial kid - should fetch JWKS
    authorization1 = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    id_token1 = create_valid_jwt_token(authorization1.nonce)
    stub_token_exchange("auth-code", id_token1, authorization1.code_verifier, redirect_uri: @redirect_uri)
    
    authorization1.exchange_code_for_identity(code: "auth-code")
    assert_requested initial_stub, times: 1
    
    # Second request with new kid - should trigger JWKS refresh due to kid_not_found
    authorization2 = EntraId::Authorization.new(redirect_uri: @redirect_uri)
    # Create token with new kid that doesn't exist in cached JWKS
    id_token2 = JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/test-tenant-id/v2.0",
        "aud" => "test-client-id",
        "exp" => Time.now.to_i + 3600,
        "iat" => Time.now.to_i,
        "oid" => "user-id",
        "preferred_username" => "test@example.com",
        "nonce" => authorization2.nonce
      },
      test_rsa_key,
      "RS256",
      { kid: "new-key-id" }
    )
    stub_token_exchange("auth-code", id_token2, authorization2.code_verifier, redirect_uri: @redirect_uri)
    
    authorization2.exchange_code_for_identity(code: "auth-code")
    # Should have fetched JWKS twice - once initially, once for kid_not_found
    assert_requested initial_stub, times: 2
  ensure
    # Restore original cache store
    Rails.cache = original_cache_store
  end
end
