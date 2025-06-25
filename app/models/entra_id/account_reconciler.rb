class EntraId::AccountReconciler
  attr_reader :directory, :sync_time

  def initialize
    @directory = EntraId::Directory.new
    @sync_time = Time.current.change(usec: 0)

    @errors = []
  end

  def reconcile
    entra_users = directory.users

    puts "[EntraID] Starting EntraId user synchronization for #{entra_users.count} users"
    entra_users.each { |entra_user| process_entra_user(entra_user) }; puts ""
    puts "[EntraId] EntraId synchronization completed"

    print_errors
  end

  private

  def print_errors
    @errors.each { |error| puts "Failed to process #{error[:login]} (#{error[:oid]}): #{error[:message]}}" }
  end

  def process_entra_user(entra_user)
    local_user = User.find_by_identity(entra_user)

    if local_user
      sync_existing_user(local_user, entra_user)
    else
      create_new_user(entra_user)
    end
     
    print "."
  rescue => e
    @errors << { login: entra_user.login, oid: entra_user.id, message: e.message }
    print "E"
  end

  def sync_existing_user(local_user, entra_user)
    local_user.sync_from_entra_user(entra_user, sync_time)
  end

  def create_new_user(entra_user)
    User.create_from_entra_user(entra_user, sync_time)
  end
end
