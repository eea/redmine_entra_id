require File.expand_path('../../../test_helper', __FILE__)

class EntraId::GroupReconcilerTest < ActiveSupport::TestCase
  test "creates new group in Redmine when EntraId group has no match" do
    entra_group = EntraId::Group.new(
      id: "12345-67890-abcdef",
      display_name: "Engineering Team",
      members: [
        { id: "user-oid-123", display_name: "John Doe" },
        { id: "user-oid-456", display_name: "Jane Smith" }
      ]
    )
    
    # Create Redmine users with matching OIDs
    user1 = User.create!(login: "jdoe_#{SecureRandom.hex(4)}", firstname: "John", lastname: "Doe", mail: "john#{SecureRandom.hex(4)}@example.com", oid: "user-oid-123")
    user2 = User.create!(login: "jsmith_#{SecureRandom.hex(4)}", firstname: "Jane", lastname: "Smith", mail: "jane#{SecureRandom.hex(4)}@example.com", oid: "user-oid-456")
    
    
    reconciler = EntraId::GroupReconciler.new
    result = reconciler.reconcile_group(entra_group)
    
    # Verify group was created
    group = Group.find_by(oid: "12345-67890-abcdef")
    assert_not_nil group
    assert_equal "🆔 Engineering Team", group.name
    assert_in_delta Time.current, group.synced_at, 1.second
    
    
    # Verify members were added
    group.reload
    assert_includes group.users, user1
    assert_includes group.users, user2
    
    # Verify result contains correct information
    assert_equal "Engineering Team", result[:name]
    assert_equal 2, result[:user_count]
    assert_equal 2, result[:users_added]
    assert_equal 0, result[:users_removed]
  end
  
  test "updates existing group in Redmine when OID matches" do
    # Create existing group with different name
    existing_group = Group.create!(lastname: "Old Name", oid: "12345-67890-abcdef")
    existing_group.update_column(:synced_at, 1.day.ago)
    
    # Create users - one already in group, one new
    user1 = User.create!(login: "existing_#{SecureRandom.hex(4)}", firstname: "Existing", lastname: "User", mail: "existing#{SecureRandom.hex(4)}@example.com", oid: "user-oid-123")
    user2 = User.create!(login: "new_#{SecureRandom.hex(4)}", firstname: "New", lastname: "User", mail: "new#{SecureRandom.hex(4)}@example.com", oid: "user-oid-456")
    user3 = User.create!(login: "removed_#{SecureRandom.hex(4)}", firstname: "Removed", lastname: "User", mail: "removed#{SecureRandom.hex(4)}@example.com", oid: "user-oid-789")
    
    # Add existing users to group
    existing_group.users << user1
    existing_group.users << user3
    
    entra_group = EntraId::Group.new(
      id: "12345-67890-abcdef",
      display_name: "Updated Engineering Team",
      members: [
        { id: "user-oid-123", display_name: "Existing User" },
        { id: "user-oid-456", display_name: "New User" }
      ]
    )
    
    reconciler = EntraId::GroupReconciler.new
    result = reconciler.reconcile_group(entra_group)
    
    # Verify group was updated
    existing_group.reload
    assert_equal "🆔 Updated Engineering Team", existing_group.name
    assert_in_delta Time.current, existing_group.synced_at, 1.second
    
    # Verify members were updated correctly
    assert_includes existing_group.users, user1  # kept
    assert_includes existing_group.users, user2  # added
    assert_not_includes existing_group.users, user3  # removed
    
    # Verify result contains correct information
    assert_equal "Updated Engineering Team", result[:name]
    assert_equal 2, result[:user_count]
    assert_equal 1, result[:users_added]
    assert_equal 1, result[:users_removed]
  end
end