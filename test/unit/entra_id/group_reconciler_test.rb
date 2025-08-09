require File.expand_path("../../../test_helper", __FILE__)

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

    frozen_time = Time.current
    reconciler = EntraId::GroupReconciler.new
    travel_to frozen_time do
      reconciler.reconcile_group(entra_group)
    end

    group = Group.find_by(oid: "12345-67890-abcdef")

    assert_not_nil group
    assert_equal "🆔 Engineering Team", group.name
    assert_equal frozen_time.to_i, group.synced_at.to_i
    assert_includes group.users, user1
    assert_includes group.users, user2
  end

  test "updates existing group in Redmine when OID matches" do
    existing_group = Group.create!(lastname: "Old Name", oid: "12345-67890-abcdef")
    existing_group.update_column(:synced_at, 1.day.ago)

    user1 = User.create!(login: "existing_#{SecureRandom.hex(4)}", firstname: "Existing", lastname: "User", mail: "existing#{SecureRandom.hex(4)}@example.com", oid: "user-oid-123")
    user2 = User.create!(login: "new_#{SecureRandom.hex(4)}", firstname: "New", lastname: "User", mail: "new#{SecureRandom.hex(4)}@example.com", oid: "user-oid-456")
    user3 = User.create!(login: "removed_#{SecureRandom.hex(4)}", firstname: "Removed", lastname: "User", mail: "removed#{SecureRandom.hex(4)}@example.com", oid: "user-oid-789")

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

    frozen_time = Time.current
    reconciler = EntraId::GroupReconciler.new
    travel_to frozen_time do
      reconciler.reconcile_group(entra_group)
    end

    existing_group.reload
    assert_equal "🆔 Updated Engineering Team", existing_group.name
    assert_equal frozen_time.to_i, existing_group.synced_at.to_i
    assert_includes existing_group.users, user1  # kept
    assert_includes existing_group.users, user2  # added
    assert_not_includes existing_group.users, user3  # removed
  end
end
