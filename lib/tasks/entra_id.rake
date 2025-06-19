namespace :entra_id do
  desc "Sync all users from Microsoft EntraID"
  task sync_users: :environment do
    puts "Starting EntraID user synchronization..."
    
    reconciler = EntraId::AccountReconciler.new
    reconciler.reconcile
  end
end
