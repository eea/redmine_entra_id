require File.expand_path('../../../test_helper', __FILE__)

class EntraId::GroupSyncTest < ActiveSupport::TestCase
  test "deletes Redmine group with OID when no longer in EntraId" do
    # Create groups in Redmine with OIDs
    group1 = Group.create!(lastname: "Group to Keep", oid: "keep-group-oid")
    group2 = Group.create!(lastname: "Group to Delete", oid: "delete-group-oid")
    
    # Add users to the group that will be deleted
    user1 = User.create!(login: "user1_#{SecureRandom.hex(4)}", firstname: "User", lastname: "One", mail: "user1#{SecureRandom.hex(4)}@example.com")
    group2.users << user1
    
    # EntraId only has one group
    entra_groups = [
      EntraId::Group.new(
        id: "keep-group-oid",
        display_name: "Group to Keep",
        members: []
      )
    ]
    
    sync = EntraId::GroupSync.new
    sync.sync_all(entra_groups)
    
    # Verify group1 still exists
    assert Group.exists?(group1.id)
    
    # Verify group2 was deleted
    assert_not Group.exists?(group2.id)
    
    # Verify user was removed from deleted group (membership deleted)
    assert_equal 0, ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM groups_users WHERE group_id = #{group2.id}")
  end
  
  test "ignores Redmine groups without OID when syncing" do
    # Create groups - one with OID, one without
    group_with_oid = Group.create!(lastname: "Group with OID", oid: "has-oid")
    group_without_oid = Group.create!(lastname: "Group without OID", oid: nil)
    
    # EntraId has no groups
    entra_groups = []
    
    sync = EntraId::GroupSync.new
    sync.sync_all(entra_groups)
    
    # Verify group with OID was deleted
    assert_not Group.exists?(group_with_oid.id)
    
    # Verify group without OID still exists
    assert Group.exists?(group_without_oid.id)
  end
  
  test "outputs group sync results with user counts and deltas" do
    # Create a group with some users
    group = Group.create!(lastname: "Test Group", oid: "test-group-oid")
    user1 = User.create!(login: "u1_#{SecureRandom.hex(4)}", firstname: "User", lastname: "One", mail: "u1#{SecureRandom.hex(4)}@example.com", oid: "user-oid-1")
    user2 = User.create!(login: "u2_#{SecureRandom.hex(4)}", firstname: "User", lastname: "Two", mail: "u2#{SecureRandom.hex(4)}@example.com", oid: "user-oid-2")
    group.users << user1
    
    entra_groups = [
      EntraId::Group.new(
        id: "test-group-oid",
        display_name: "Test Group",
        members: [
          { id: "user-oid-1", display_name: "User One" },
          { id: "user-oid-2", display_name: "User Two" }
        ]
      )
    ]
    
    # Capture output
    output = capture_io do
      sync = EntraId::GroupSync.new
      sync.sync_all(entra_groups)
    end
    
    # Verify output format
    assert_match(/Synced group 'Test Group': 2 users \(1 added, 0 removed\)/, output.join)
  end
end