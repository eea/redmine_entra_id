module GraphTestHelper
  extend ActiveSupport::Concern

  def setup_graph_access_token(token = "mock_access_token")
    stub_request(:post, EntraId::Graph::AccessToken.uri)
      .to_return(
        status: 200,
        body: {
          "access_token" => token,
          "token_type" => "Bearer",
          "expires_in" => 3600
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def setup_entra_users(users = [])
    # Match the users endpoint with any query parameters
    users_url_pattern = /https:\/\/graph\.microsoft\.com\/v1\.0\/users\?/

    user_data = users.map do |user|
      {
        "id" => user[:oid] || user[:id],
        "mail" => user[:email] || user[:mail],
        "userPrincipalName" => user[:email] || user[:mail] || user[:userPrincipalName],
        "givenName" => user[:given_name] || user[:givenName],
        "surname" => user[:surname],
        "displayName" => user[:display_name] || "#{user[:given_name]} #{user[:surname]}"
      }
    end

    stub_request(:get, users_url_pattern).to_return(
      status: 200,
      body: { value: user_data }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end
end
