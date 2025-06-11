class EntraId::Directory
  def authenticate
    uri = URI("https://login.microsoftonline.com/#{EntraId.tenant_id}/oauth2/v2.0/token")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({
      "grant_type" => "client_credentials",
      "client_id" => EntraId.client_id,
      "client_secret" => EntraId.client_secret,
      "scope" => "https://graph.microsoft.com/.default"
    })

    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      token_data = JSON.parse(response.body)
      token_data["access_token"]
    else
      raise "Authentication failed: #{response.code} #{response.body}"
    end
  end

  def users
    access_token = authenticate
    fetch_users(access_token)
  end

    def fetch_users(access_token)
      all_users = []
      next_link = "https://graph.microsoft.com/v1.0/users"
      
      while next_link
        data = fetch_page(access_token, next_link)
        all_users.concat(parse_users(data["value"] || []))
        next_link = data["@odata.nextLink"]
      end
      
      all_users
    end

    def fetch_page(access_token, url)
      uri = URI(url)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Accept"] = "application/json"

      response = http.request(request)
      
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
          email: user_json["mail"] || user_json["userPrincipalName"],
          given_name: user_json["givenName"],
          surname: user_json["surname"]
        )
      end
    end
end
