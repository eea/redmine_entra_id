module EntraId
  class GroupReconciler
    def reconcile_group(entra_group)
      group = find_or_create_group(entra_group)

      # Update group name with ID emoji prefix
      group.lastname = "🆔 #{entra_group.display_name}"
      group.synced_at = Time.current
      group.save!

      # Sync group members
      users_added, users_removed = sync_members(group, entra_group)

      # Reload to ensure user count is accurate
      group.reload

      {
        name: entra_group.display_name,
        user_count: group.users.count,
        users_added: users_added,
        users_removed: users_removed
      }
    end

    private

    def find_or_create_group(entra_group)
      ::Group.find_or_initialize_by(oid: entra_group.id)
    end

    def sync_members(group, entra_group)
      # Find Redmine users by their OIDs
      member_oids = entra_group.members.map { |m| m[:id] }
      redmine_users = ::User.where(oid: member_oids).where.not(type: "Group") # exclude groups


      # Get current members
      current_members = group.users.to_a

      # Calculate differences
      users_to_add = redmine_users - current_members
      users_to_remove = current_members - redmine_users


      # Remove users no longer in the group
      users_to_remove.each do |user|
        group.users.delete(user)
      end

      # Add new users to the group
      users_to_add.each do |user|
        group.users << user
      end

      [ users_to_add.count, users_to_remove.count ]
    end
  end
end
