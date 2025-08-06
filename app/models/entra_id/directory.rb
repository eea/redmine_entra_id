class EntraId::Directory
  def users
    @users ||= build_users
  end

  def groups
    @groups ||= build_groups
  end

  private

    def build_users
      user_data = graph_query.users
      user_data.map do |user_json|
        EntraId::User.new(user_json.with_indifferent_access)
      end
    end

    def build_groups
      puts "Loading groups from Entra..."

      group_data = graph_query.groups
      groups = group_data.map do |group_json|
        EntraId::Group.new(
          id: group_json["id"],
          display_name: group_json["displayName"]
        )
      end

      puts "Total groups: #{groups.size}"
      groups
    end

    def graph_query
      @graph_query ||= EntraId::Graph::Query.new
    end
end
