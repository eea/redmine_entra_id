class EntraId::Directory
  GRAPH_API_BASE = "https://graph.microsoft.com/v1.0"
  TOKEN_ENDPOINT_BASE = "https://login.microsoftonline.com"
  OAUTH_SCOPE = "https://graph.microsoft.com/.default"
  USERS_ENDPOINT = "#{GRAPH_API_BASE}/users"

  def self.token_endpoint_uri
    URI("#{TOKEN_ENDPOINT_BASE}/#{EntraId.tenant_id}/oauth2/v2.0/token")
  end

  def users
    @users ||= fetch_users(access_token)
  end

  private

    def access_token
      uri = self.class.token_endpoint_uri
      response = make_token_request(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        token_data = JSON.parse(response.body)
        token_data["access_token"]
      else
        raise "Authentication failed: #{response.code} #{response.body}"
      end
    end

    def make_token_request(uri)
      client = EntraId::HttpClient.new(uri)
      body = URI.encode_www_form({
        "grant_type" => "client_credentials",
        "client_id" => EntraId.client_id,
        "client_secret" => EntraId.client_secret,
        "scope" => OAUTH_SCOPE
      })
      client.post(uri.request_uri, body, {
        "Content-Type" => "application/x-www-form-urlencoded"
      })
    end

    def fetch_users(access_token)
      all_users = []
      next_link = USERS_ENDPOINT
      
      while next_link
        data = fetch_page(access_token, next_link)
        all_users.concat(parse_users(data["value"] || []))
        next_link = data["@odata.nextLink"]
      end
      
      all_users
    end

    def fetch_page(access_token, url)
      uri = URI(url)
      
      client = EntraId::HttpClient.new(uri)
      response = client.get(uri.request_uri, {
        "Authorization" => "Bearer #{access_token}",
        "Accept" => "application/json"
      })
      
      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        raise "Failed to fetch users: #{response.code} #{response.body}"
      end
    end

    def parse_users(user_data)
      user_data.map do |user_json|
        EntraId::User.new(
          oid: user_json["id"],
          login: user_json["userPrincipalName"],
          email: user_json["mail"] || user_json["userPrincipalName"],
          given_name: user_json["givenName"],
          surname: user_json["surname"]
        )
      end
    end
end
