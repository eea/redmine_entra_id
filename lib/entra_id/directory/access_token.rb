class EntraId::Directory::AccessToken
  attr_reader :grant_type, :scope

  def initialize(grant_type:, scope:)
    @grant_type = grant_type
    @scope = scope
  end

  def value
    read_cached_value || write_to_cache_and_return
  end

  private

  def cache_key
    "entra_id_#{grant_type}_token"
  end

  def read_cached_value
    Rails.cache.read(cache_key)
  end

  def write_to_cache_and_return
    token_data = fetch_token_data
    Rails.cache.write(cache_key, token_data["access_token"], expires_in: token_data["expires_in"].seconds)
    token_data["access_token"]
  end
  
  def fetch_token_data
    uri = URI(EntraId.token_endpoint_url)
    client = EntraId::HttpClient.new(uri)
    
    body = URI.encode_www_form({
      "grant_type" => grant_type,
      "client_id" => EntraId.client_id,
      "client_secret" => EntraId.client_secret,
      "scope" => scope
    })
    
    response = client.post(uri.request_uri, body, {
      "Content-Type" => "application/x-www-form-urlencoded"
    })
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "Token authentication failed: #{response.code} #{response.body}"
      raise EntraId::NetworkError, "Authentication failed: #{response.code}"
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse token response: #{e.message}"
    raise EntraId::NetworkError, "Invalid token response"
  end
end