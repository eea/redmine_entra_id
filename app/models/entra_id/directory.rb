class EntraId::Directory
  def users
    @users ||= fetch_all_users
  end

  def groups
    @groups ||= fetch_all_groups
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
        Rails.logger.error "Failed to fetch page: #{response.code} #{response.body}"
        Rails.logger.error "URL was: #{url}"
        raise EntraId::NetworkError, "Failed to fetch: #{response.code}"
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse users response: #{e.message}"
      raise EntraId::NetworkError, "Invalid users response"
    end

    def parse_users(user_data)
      user_data.map do |user_json|
        EntraId::User.new(user_json.with_indifferent_access)
      end
    end

    def fetch_all_groups
      all_groups = []
      next_link = "https://graph.microsoft.com/v1.0/groups?$select=id,displayName&$top=100"

      while next_link
        data = fetch_page(next_link)
        groups = parse_groups(data["value"] || [])

        # Fetch members for each group
        groups.each do |group|
          fetch_group_members(group)
        end

        all_groups.concat(groups)
        next_link = data["@odata.nextLink"]
      end

      all_groups
    end

    def parse_groups(group_data)
      group_data.map do |group_json|
        EntraId::Group.new(
          id: group_json["id"],
          display_name: group_json["displayName"],
          members: []
        )
      end
    end

    def fetch_group_members(group)
      # First try to get direct members to check if there are nested groups
      members_url = "https://graph.microsoft.com/v1.0/groups/#{group.id}/members?$select=id,displayName&$top=999"
      members_data = fetch_page(members_url)

      # Check if there are any nested groups
      has_nested_groups = members_data["value"]&.any? { |m| m["@odata.type"] == "#microsoft.graph.group" }

      if has_nested_groups
        # Use transitiveMembers to get all users from nested groups
        transitive_url = "https://graph.microsoft.com/v1.0/groups/#{group.id}/transitiveMembers?$select=id,displayName&$top=999"
        transitive_data = fetch_page(transitive_url)
        # Filter to only include users (not groups)
        members = (transitive_data["value"] || []).select { |m| m["@odata.type"] == "#microsoft.graph.user" }
      else
        # Just use direct members if no nested groups
        members = members_data["value"]&.select { |m| m["@odata.type"] == "#microsoft.graph.user" } || []
      end

      group.members = members.map do |member|
        {
          id: member["id"],
          display_name: member["displayName"]
        }
      end
    end
end
