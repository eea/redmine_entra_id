module EntraIdDirectoryHelper
  def self.included(base)
    base.setup do
      stub_entra_id_token
    end
  end

  def stub_entra_id_token(access_token: "mock_access_token")
    token_url = "https://login.microsoftonline.com/#{EntraId.tenant_id}/oauth2/v2.0/token"
    
    stub_request(:post, token_url)
      .with(
        body: {
          "grant_type" => "client_credentials",
          "client_id" => EntraId.client_id,
          "client_secret" => EntraId.client_secret,
          "scope" => "https://graph.microsoft.com/.default"
        }
      )
      .to_return(
        status: 200,
        body: {
          "access_token" => access_token,
          "token_type" => "Bearer",
          "expires_in" => 3600
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def setup_entra_users(users = [])
    users_url = "https://graph.microsoft.com/v1.0/users"
    
    user_data = users.map do |user|
      {
        "id" => user[:oid] || user[:id],
        "mail" => user[:email] || user[:mail],
        "userPrincipalName" => user[:email] || user[:mail] || user[:userPrincipalName],
        "givenName" => user[:given_name] || user[:givenName],
        "surname" => user[:surname]
      }
    end
    
    stub_request(:get, users_url).to_return(
      status: 200,
      body: { value: user_data }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end
end
