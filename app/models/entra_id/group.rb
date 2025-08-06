module EntraId
  class Group
    attr_accessor :id, :display_name
    attr_writer :members

    def initialize(attributes = {})
      @id = attributes[:id]
      @display_name = attributes[:display_name]
      @members = attributes[:members] if attributes.key?(:members)
    end

    def members
      @members ||= fetch_members
    end

    private

    def fetch_members
      return [] unless @id

      member_data = graph_query.group_transitive_members(@id)
      members = member_data.map { |member| { id: member["id"] } }
      members
    end

    def graph_query
      @graph_query ||= EntraId::Graph::Query.new
    end
  end
end
