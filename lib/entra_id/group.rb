class EntraId::Group
  PREFIX = "🆔"
  MAX_LENGTH = 255

  class << self
    def sync_all
      client = EntraId::Graph::Client.new
      errors = []

      client.perform do |c|
        tuples = c.get("groups", select: [ "id", "displayName" ], top: 999)

        puts "Found #{tuples.size} groups"

        tuples.each do |tuple|
          begin
            members = c.get("groups/#{tuple["id"]}/transitiveMembers", select: "id", top: 999)
            group = EntraId::Group.new(oid: tuple["id"], display_name: tuple["displayName"], members: members)

            group.sync

            print "."
          rescue => e
            errors << "Failed to process #{tuple["displayName"]} (#{tuple["id"]}): #{e.message}"
            print "E"
          end
        end
      end

      if errors.present?
        puts "\n\nFailures"
        puts "========"
        errors.each { |error| puts error }
      end
    end
  end

  def initialize(oid:, display_name:, members: [])
    @oid = oid
    @display_name = display_name
    @members = members
  end

  def name
    name_already_used? ? name_with_prefix_and_unique_suffix : name_with_prefix
  end

  def sync
    create_or_update_associated_group
    create_or_update_memberships
  end

  private

    def name_already_used?
      Group.where.not(oid: @oid).where(lastname: name_with_prefix).exists?
    end

    def name_with_prefix
      "#{PREFIX} #{@display_name[0, MAX_LENGTH]}"
    end

    def name_with_prefix_and_unique_suffix
      "#{PREFIX} #{@display_name[0, MAX_LENGTH - uniqueness_suffix.length]} #{uniqueness_suffix}"
    end

    def uniqueness_suffix
      " (#{@oid.split("-").first})"
    end

    def create_or_update_associated_group
      @group = ::Group.find_or_initialize_by(oid: @oid)
      @group.lastname = name
      @group.save!
    end

    def create_or_update_memberships
      return unless @group

      member_oids = @members.map { |m| m["id"] }
      user_ids = ::User.where(oid: member_oids).where.not(type: "Group").pluck(:id)
      
      # Delete all existing memberships
      @group.users.delete_all
      
      # Bulk assign new users (Rails handles the insert)
      @group.user_ids = user_ids
    end
end
