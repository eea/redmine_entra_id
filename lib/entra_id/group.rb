class EntraId::Group
  PREFIX = "🆔"

  attr_reader :id

  def initialize(attrs = {})
    @id = attrs[:id]
    @display_name = attrs[:display_name]
    @members = attrs.fetch(:members, [])
  end

  # Returns the raw display name from Entra ID (no prefix)
  def display_name
    @display_name
  end

  # Returns the prefixed name used in Redmine
  def prefixed_name
    "#{PREFIX} #{display_name}"
  end

  # Redmine users represented in this group (array of hashes with :id keys)
  def members
    @members
  end

  # Find or create/update the corresponding Redmine::Group and sync members.
  # Returns a summary hash like the former reconciler.
  def reconcile!
    group = ::Group.find_or_initialize_by(oid: id)

    # Compute unique name with prefix; avoid collisions with other groups
    new_name = unique_name_for(group)
    group.lastname = new_name if group.lastname != new_name

    group.synced_at = Time.current
    group.save!

    users_added, users_removed = sync_members!(group)

    group.reload

    {
      name: display_name,
      user_count: group.users.count,
      users_added: users_added,
      users_removed: users_removed
    }
  end

  private

  def unique_name_for(group)
    base = prefixed_name
    # If another group already has this name, append short oid
    existing = ::Group.where.not(id: group.id).where(lastname: base).first
    return base unless existing

    "#{base} (#{id.to_s[0..7]})"
  end

  def sync_members!(group)
    member_oids = members.map { |m| m[:id] }
    redmine_users = ::User.where(oid: member_oids).where.not(type: "Group")

    current_members = group.users.to_a

    users_to_add = redmine_users - current_members
    users_to_remove = current_members - redmine_users

    users_to_remove.each { |u| group.users.delete(u) }
    users_to_add.each { |u| group.users << u }

    [ users_to_add.count, users_to_remove.count ]
  end
end
