class EntraId::AccountReconciler
  attr_reader :results

  def initialize
    @results = []

    @directory = EntraId::Directory.new
    @sync_time = Time.current.change(usec: 0)
  end


  def reconcile
    reset_results
    import_entra_users
    disable_stale_users
  end

  def print_summary
    puts "Synced accounts"
    puts "==================================="
    @results.select(&:success?).each do |result|
      puts result
    end
    
    puts "Failed accounts"
    puts "==================================="
    @results.select(&:error?).each do |result|
      puts result
    end
  end

  private

  def reset_results
    @results = []
  end

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
    local_user.update!(
      firstname: entra_user.given_name,
      lastname: entra_user.surname,
      mail: entra_user.email,
      status: User::STATUS_ACTIVE,
      synced_at: @sync_time,
      oid: entra_user.oid,
      auth_source_id: 1
    )

    @results << EntraId::SyncResult.new(
      entra_user: entra_user,
      local_user: local_user,
      operation: "updated"
    )
  rescue => e
    @results << EntraId::SyncResult.new(
      entra_user: entra_user,
      local_user: local_user,
      operation: "updated",
      status: "error",
      error: e.message
    )
  end

  def disable_stale_users
    scope = User.not_admin.stale_since(@sync_time)
    scope = scope.identified unless EntraId.exclusive?

    scope.find_each do |local_user|
      deactivate_local_user(local_user)
    end
  end

  def create_local_user(entra_user)
    new_user = User.create!(
      login: entra_user.preferred_username,
      firstname: entra_user.given_name,
      lastname: entra_user.surname,
      mail: entra_user.email,
      status: User::STATUS_ACTIVE,
      oid: entra_user.oid,
      synced_at: @sync_time,
      auth_source_id: 1
    )

    @results << EntraId::SyncResult.new(
      entra_user: entra_user,
      local_user: new_user,
      operation: "created"
    )
  rescue => e
    @results << EntraId::SyncResult.new(
      entra_user: entra_user,
      operation: "created",
      status: "error",
      error: e.message
    )
  end

  def deactivate_local_user(local_user)
    local_user.lock!

    @results << EntraId::SyncResult.new(
      local_user: local_user,
      operation: "deactivated"
    )
  end
end
