module EntraId
  class GroupSync
    def sync_all(entra_groups)
      # Create a map of EntraId group OIDs for quick lookup
      entra_group_oids = entra_groups.map(&:id).to_set
      
      # Process each EntraId group
      entra_groups.each do |entra_group|
        reconciler = GroupReconciler.new
        result = reconciler.reconcile_group(entra_group)
        
        # Output the result
        puts "Synced group '#{result[:name]}': #{result[:user_count]} users (#{result[:users_added]} added, #{result[:users_removed]} removed)"
      end
      
      # Delete Redmine groups with OIDs that no longer exist in EntraId
      groups_to_delete = ::Group.where.not(oid: nil).where.not(oid: entra_group_oids)
      
      groups_to_delete.each do |group|
        group_name = group.name
        user_count = group.users.count
        
        # Delete the group (this will also remove all group memberships)
        group.destroy
        
        puts "Deleted group '#{group_name}': removed #{user_count} users"
      end
    end
  end
end