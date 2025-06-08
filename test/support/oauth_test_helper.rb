module OauthTestHelper
  def stub_oauth_token_exchange(code:, access_token: "mock-access-token", id_token: nil, expires_in: 3600)
    token_endpoint = "https://login.microsoftonline.com/tenant-id/oauth2/v2.0/token"

    response_body = {
      access_token: access_token,
      token_type: "Bearer",
      expires_in: expires_in,
      scope: "openid profile email"
    }

    response_body[:id_token] = id_token if id_token

    stub_request(:post, token_endpoint)
      .with(
        body: hash_including({
          "grant_type" => "authorization_code",
          "code" => code
        })
      )
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

  def stub_full_oauth_flow(code: "test-code", access_token: "mock-access-token", user_data: {})
    stub_oauth_token_exchange(code: code, access_token: access_token)
    stub_oauth_user_info(access_token: access_token, user_data: user_data)
  end
end
