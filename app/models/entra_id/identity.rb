class EntraId::Identity
  GRAPH_HOST = "graph.microsoft.com"
  GRAPH_PATH = "/v1.0/me"

  def initialize(claims:, access_token:)
    @claims = claims
    @access_token = access_token
  end

  def id
    @claims["oid"]
  end

  def first_name
    user_info["givenName"]
  end

  def last_name
    user_info["surname"]
  end

  def preferred_username
    @claims["preferred_username"]
  end

  def to_user_params
    {
      login: preferred_username,
      firstname: first_name,
      lastname: last_name,
      mail: preferred_username
    }
  end

  def registration
    user = User.new(
      login: preferred_username,
      firstname: first_name,
      lastname: last_name,
      mail: preferred_username
    )

    user
  end

  def user_info
    @user_info ||= fetch_user_info
  end

  def fetch_user_info
    uri = URI("https://#{GRAPH_HOST}/v1.0/me")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Authorization"] = "Bearer #{@access_token}"
    request["Accept"] = "application/json"

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      {}
    end
  end
end
