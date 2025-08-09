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
    
    assert Group.exists?(group1.id)
    assert_not Group.exists?(group2.id)
  end
  
  test "ignores Redmine groups without OID when syncing" do
    group_with_oid = Group.create!(lastname: "Group with OID", oid: "has-oid")
    group_without_oid = Group.create!(lastname: "Group without OID", oid: nil)
    
    sync = EntraId::GroupSync.new
    sync.sync_all([])
    
    assert_not Group.exists?(group_with_oid.id)
    assert Group.exists?(group_without_oid.id)
  end
end