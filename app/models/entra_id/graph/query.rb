class EntraId::Graph::Query
  API_BASE = "https://graph.microsoft.com/v1.0"
  OAUTH_SCOPE = "https://graph.microsoft.com/.default"

  MAX_PAGE_SIZE = 999

  class << self
    def users_url(select: "id")
      "#{API_BASE}/users?#{query_params("$select" => select, "$top" => MAX_PAGE_SIZE)}"
    end

    def groups_url(select: "id")
      "#{API_BASE}/groups?#{query_params("$select" => select, "$top" => MAX_PAGE_SIZE)}"
    end

    def group_members_url(group_id, select: "id")
      "#{API_BASE}/groups/#{group_id}/transitiveMembers?#{query_params("$select" => select, "$top" => MAX_PAGE_SIZE)}"
    end

    private

      def query_params(params = {})
        params.map { |k, v| "#{k}=#{Array.wrap(v).join(",")}" }.join("&")
      end
  end

  def users
    url = EntraId::Graph::Query.users_url(select: [ "id", "userPrincipalName", "mail", "givenName", "surname", "displayName" ])
    get_all_pages(url)
  end

  def groups
    get_all_pages(EntraId::Graph::Query.groups_url(select: [ "id", "displayName" ]))
  end

  def group_transitive_members(group_id)
    data = fetch_page(EntraId::Graph::Query.group_members_url(group_id))

    # Filter to only include users (not groups)
    (data["value"] || []).select { |m| m["@odata.type"] == "#microsoft.graph.user" }
  end

  private

  def access_token
    @access_token ||= EntraId::Directory::AccessToken.new(
      grant_type: "client_credentials",
      scope: EntraId::GRAPH_OAUTH_SCOPE
    )
  end

  def get_all_pages(url)
    results = []
    next_link = url

    while next_link
      data = fetch_page(next_link)
      results.concat(data["value"] || [])
      next_link = data["@odata.nextLink"]
    end

    results
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
      Rails.logger.error "Failed to fetch page: #{response.code} #{response.body}"
      Rails.logger.error "URL was: #{url}"
      raise EntraId::NetworkError, "Failed to fetch: #{response.code}"
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse response: #{e.message}"
    raise EntraId::NetworkError, "Invalid response from Graph API"
  end
end
