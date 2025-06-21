class EntraId::Directory
  def users
    @users ||= fetch_all_users
  end

  private

    def access_token
      @access_token ||= AccessToken.new(grant_type: "client_credentials", scope: EntraId::GRAPH_OAUTH_SCOPE)
    end

    def fetch_all_users
      all_users = []
      next_link = EntraId::GRAPH_USERS_ENDPOINT
      
      while next_link
        data = fetch_page(next_link)
        all_users.concat(parse_users(data["value"] || []))
        next_link = data["@odata.nextLink"]
      end
      
      all_users
    end

    def fetch_page(url)
      uri = URI(url)
      
      client = EntraId::HttpClient.new(uri)
      response = client.get(uri.request_uri, {
        "Authorization" => "Bearer #{access_token.value}",
        "Accept" => "application/json"
      })
        
      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        Rails.logger.error "Failed to fetch users page: #{response.code} #{response.body}"
        raise EntraId::NetworkError, "Failed to fetch users: #{response.code}"
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse users response: #{e.message}"
      raise EntraId::NetworkError, "Invalid users response"
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
