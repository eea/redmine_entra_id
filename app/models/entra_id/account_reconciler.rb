class EntraId::AccountReconciler
  def initialize
    @directory = EntraId::Directory.new
    @sync_time = Time.current.change(usec: 0)
  end

  def reconcile
    import_entra_users
  end

  private

  def import_entra_users
    entra_users = @directory.users

    # Process each EntraID user (create/update with OID and sync time)
    entra_users.each do |entra_user|
      local_user = User.find_by_identity(entra_user)

      if local_user
        sync_local_user(local_user, entra_user)
      else
        create_local_user(entra_user)
      end
    end
  end

  def sync_local_user(local_user, entra_user)
    local_user.sync_from_entra_user(entra_user, @sync_time)
  end

  def create_local_user(entra_user)
    User.create_from_entra_user(entra_user, @sync_time)
  end
end
