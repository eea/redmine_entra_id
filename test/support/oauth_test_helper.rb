module OauthTestHelper
  def stub_oauth_token_exchange(code:, access_token: "mock-access-token", id_token: nil, expires_in: 3600, code_verifier: nil)
    token_endpoint = "https://login.microsoftonline.com/test-tenant-id/oauth2/v2.0/token"

    response_body = {
      access_token: access_token,
      token_type: "Bearer",
      expires_in: expires_in,
      scope: "openid profile email"
    }

    response_body[:id_token] = id_token if id_token

    # Build the expected parameters
    expected_params = {
      "grant_type" => "authorization_code",
      "code" => code,
      "redirect_uri" => "http://www.example.com/entra_id/callback"
    }
    
    # Add code_verifier if provided (for PKCE)
    expected_params["code_verifier"] = code_verifier if code_verifier

    # Use the most permissive stub to match any OAuth token request
    stub_request(:post, token_endpoint)
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_oauth_user_info(access_token: "mock-access-token", user_data: {})
    userinfo_endpoint = "https://graph.microsoft.com/v1.0/me"

    default_user_data = {
      id: "user-12345",
      displayName: "Test User",
      mail: "test@example.com",
      givenName: "Test",
      surname: "User"
    }

    response_body = default_user_data.merge(user_data)

    stub_request(:get, userinfo_endpoint)
      .with(
        headers: {
          "Authorization" => "Bearer #{access_token}"
        }
      )
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_full_oauth_flow(code: "test-code", access_token: "mock-access-token", user_data: {}, code_verifier: nil)
    stub_oauth_token_exchange(code: code, access_token: access_token, code_verifier: code_verifier)
    stub_oauth_user_info(access_token: access_token, user_data: user_data)
  end

  # JWT and OIDC specific helpers

  def stub_token_exchange(code, id_token, code_verifier, redirect_uri: "https://example.com/callback")
    token_endpoint = "https://login.microsoftonline.com/test-tenant-id/oauth2/v2.0/token"
    
    # Structure response to avoid OAuth2 library warnings about multiple token keys
    response_body = {
      "access_token" => "mock-access-token",
      "token_type" => "Bearer",
      "expires_in" => 3600,
      "scope" => "openid profile email",
      "id_token" => id_token
    }

    stub_request(:post, token_endpoint)
      .with(body: hash_including({
        "grant_type" => "authorization_code",
        "code" => code,
        "redirect_uri" => redirect_uri,
        "code_verifier" => code_verifier
      }))
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_jwks_endpoint
    jwks_endpoint = "https://login.microsoftonline.com/test-tenant-id/discovery/v2.0/keys"
    
    # Create a real RSA key for testing
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

    stub_request(:get, jwks_endpoint)
      .to_return(
        status: 200,
        body: jwks_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def create_valid_jwt_token(nonce)
    payload = {
      "iss" => "https://login.microsoftonline.com/test-tenant-id/v2.0",
      "aud" => "test-client-id",
      "exp" => Time.now.to_i + 3600,
      "iat" => Time.now.to_i,
      "oid" => "user-id",
      "preferred_username" => "test@example.com",
      "nonce" => nonce
    }

    JWT.encode(payload, test_rsa_key, "RS256", { kid: "test-key-id" })
  end

  def create_invalid_jwt_token
    # Create a JWT with a wrong signature to trigger verification error
    payload = {
      "iss" => "https://login.microsoftonline.com/test-tenant-id/v2.0",
      "aud" => "test-client-id",
      "exp" => Time.now.to_i + 3600,
      "iat" => Time.now.to_i,
      "oid" => "user-id",
      "preferred_username" => "test@example.com",
      "nonce" => "test-nonce"
    }

    # Use a different key to make verification fail
    JWT.encode(payload, wrong_rsa_key, "RS256", { kid: "test-key-id" })
  end

  private

    def test_rsa_key
      @test_rsa_key ||= begin
        plugin_root = File.expand_path("../../..", __FILE__)
        fixture_path = File.join(plugin_root, "test", "fixtures", "test_rsa_key.pem")
        OpenSSL::PKey::RSA.new(File.read(fixture_path))
      end
    end

    def wrong_rsa_key
      @wrong_rsa_key ||= begin
        plugin_root = File.expand_path("../../..", __FILE__)
        fixture_path = File.join(plugin_root, "test", "fixtures", "wrong_rsa_key.pem")
        OpenSSL::PKey::RSA.new(File.read(fixture_path))
      end
    end
end
