class EntraId::AccountReconciler
  attr_reader :directory, :sync_time

  def initialize
    @directory = EntraId::Directory.new
    @sync_time = Time.current.change(usec: 0)
  end

  def reconcile
    entra_users = directory.users
    Rails.logger.info "Starting EntraId user synchronization for #{entra_users.count} users"
    
    entra_users.each do |entra_user|
      process_entra_user(entra_user)
    end
    
    Rails.logger.info "EntraId synchronization completed"
  end

  private

  def process_entra_user(entra_user)
    local_user = User.find_by_identity(entra_user)

    if local_user
      sync_existing_user(local_user, entra_user)
    else
      create_new_user(entra_user)
    end
  rescue => e
    Rails.logger.error "Failed to process EntraId user #{entra_user.email}: #{e.message}"
  end

  def sync_existing_user(local_user, entra_user)
    local_user.sync_from_entra_user(entra_user, sync_time)
  end

  def create_new_user(entra_user)
    User.create_from_entra_user(entra_user, sync_time)
  end
end
