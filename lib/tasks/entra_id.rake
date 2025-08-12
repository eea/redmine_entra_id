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

  ##
  # Temporary scripts
  #
  # The tasks below are meant to repair a bug discovered after a full sync
  task reset_auth_sources: :environment do
    auth_source = AuthSourceLdap.first
    logins = auth_source.send :ldap_users

    User.active.where(auth_source: nil).find_each do |user|
      user.update(auth_source: auth_source) if logins[:enabled].include?(user.login)
    end
  end

  task reset_logins: :environment do
    auth_source = AuthSourceLdap.first

    def auth_source.original_user_login_for(email, options = {})
      user_filter = Net::LDAP::Filter.eq(:objectclass, setting.class_user)
      email_filter = Net::LDAP::Filter.eq(setting.mail, email)

      result = with_ldap_connection(options[:login], options[:password]) do |ldap|
        ldap_search(
          ldap, 
          { base: setting.base_dn, filter: user_filter & email_filter }
        ).first
      end

      result[:uid].first if result.present? && result[:uid]
    end

    User.active.where.not(oid: nil).find_each do |user|
      current_login = user.login
      original_login = auth_source.original_user_login_for(current_login)

      if original_login
         print "Updating #{current_login}->#{original_login}..."

        begin
          user.update!(login: original_login)
          puts "Done"
        rescue => e
          puts "Failed: #{e.message}"
        end
      end
    end
  end
end
