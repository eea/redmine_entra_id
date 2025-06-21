class EntraId::Identity
  attr_reader :claims, :access_token

  def initialize(claims:, access_token:)
    @claims = claims
    @access_token = access_token
  end

  def id
    claims["oid"]
  end

  def preferred_username
    claims["preferred_username"]
  end

  def first_name
    nametag.first_name
  end

  def last_name
    nametag.last_name
  end

  def to_user_params
    {
      login: preferred_username,
      firstname: first_name,
      lastname: last_name,
      mail: preferred_username,
      oid: id,
      synced_at: Time.current
    }
  end

  def user_info
    @user_info ||= fetch_user_info
  end

  private

  def nametag
    @nametag ||= EntraId::Nametag.new(
      given_name: user_info["givenName"],
      surname: user_info["surname"],
      display_name: user_info["displayName"]
    )
  end

  def fetch_user_info
    uri = URI(EntraId::GRAPH_IDENTITY_URL)
    client = EntraId::HttpClient.new(uri)
    
    response = client.get(uri.request_uri, {
      "Authorization" => "Bearer #{access_token}",
      "Accept" => "application/json"
    })

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "Failed to fetch user info: #{response.code} #{response.body}"
      {}
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse user info response: #{e.message}"
    {}
  end
end
