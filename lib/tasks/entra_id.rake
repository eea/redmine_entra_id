namespace :entra_id do
  namespace :sync do
    desc "Sync all users from Microsoft EntraID"
    task users: :environment do
      puts "Starting EntraID user synchronization..."
      
      EntraId::User.sync_all
    end
    
    desc "Sync all groups from Microsoft EntraID"
    task groups: :environment do
      puts "Starting EntraID group synchronization..."
      
      EntraId::Group.sync_all
      
      puts "Group synchronization completed."
    end
  end
  
  desc "Sync users and groups from Microsoft EntraID"
  task sync: :environment do
    Rake::Task['entra_id:sync:users'].invoke
    Rake::Task['entra_id:sync:groups'].invoke
  end
end
