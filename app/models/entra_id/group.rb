module EntraId
  class Group
    attr_accessor :id, :display_name, :members
    
    def initialize(attributes = {})
      @id = attributes[:id]
      @display_name = attributes[:display_name]
      @members = attributes[:members] || []
    end
  end
end