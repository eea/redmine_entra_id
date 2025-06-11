namespace :entra_id do
  desc "Sync all users from Microsoft EntraID"
  task sync_users: :environment do
    puts "Starting EntraID user synchronization..."
    
    directory = EntraId::Directory.new
    successful_count = 0
    failed_users = []
    
    directory.users.each_slice(100) do |user_batch|
      user_batch.each do |user|
        begin
          if user.replicate_locally!
            successful_count += 1
          else
            failed_users << user
          end
        rescue => e
          Rails.logger.error "Failed to sync user #{user.email}: #{e.message}"
          failed_users << user
        end
      end
      
      # Progress update every 1000 users
      if (successful_count + failed_users.size) % 1000 == 0
        puts "Processed #{successful_count + failed_users.size} users..."
      end
    end
    
    puts "\n=== Synchronization Complete ==="
    puts "Successfully processed: #{successful_count}"
    puts "Failed: #{failed_users.size}"
    
    if failed_users.any?
      puts "\nFailed Users:"
      puts "| Email                    | Name"
      puts "|--------------------------|----------------------"
      
      failed_users.each do |user|
        email = user.email || "N/A"
        name = "#{user.given_name} #{user.surname}".strip
        name = "N/A" if name.blank?
        
        puts "| #{email.ljust(24)} | #{name}"
      end
      puts "\nCheck the Rails log for detailed error messages."
    end
  end
end
