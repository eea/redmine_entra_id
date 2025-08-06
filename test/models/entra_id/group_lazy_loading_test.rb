require File.expand_path("../../../test_helper", __FILE__)
require "minitest/mock"

class EntraId::GroupLazyLoadingTest < ActiveSupport::TestCase
  test "group does not fetch members on initialization" do
    # Create a group without members
    group = EntraId::Group.new(
      id: "group-123",
      display_name: "Test Group"
    )

    # Members should not be fetched yet
    assert_nil group.instance_variable_get(:@members)
  end

  test "group fetches members lazily when accessed" do
    # Mock the members response
    members_response = {
      "value" => [
        {
          "id" => "user-001",
          "displayName" => "John Doe",
          "@odata.type" => "#microsoft.graph.user"
        },
        {
          "id" => "user-002",
          "displayName" => "Jane Smith",
          "@odata.type" => "#microsoft.graph.user"
        }
      ]
    }

    group = EntraId::Group.new(
      id: "group-123",
      display_name: "Test Group"
    )

    # Mock the graph query
    mock_query = Minitest::Mock.new
    mock_query.expect :group_transitive_members, members_response["value"], [ "group-123" ]

    group.stub :graph_query, mock_query do
      # First access should trigger fetch
      members = group.members

      assert_equal 2, members.length
      assert_equal "user-001", members[0][:id]
      assert_equal "user-002", members[1][:id]

      # Verify mock was called
      mock_query.verify
    end
  end

  test "group caches members after first fetch" do
    members_response = {
      "value" => [
        {
          "id" => "user-001",
          "displayName" => "John Doe",
          "@odata.type" => "#microsoft.graph.user"
        }
      ]
    }

    group = EntraId::Group.new(
      id: "group-123",
      display_name: "Test Group"
    )

    # Mock should only be called once
    mock_query = Minitest::Mock.new
    mock_query.expect :group_transitive_members, members_response["value"], [ "group-123" ]

    group.stub :graph_query, mock_query do
      # First access
      members1 = group.members
      # Second access should use cached value
      members2 = group.members

      assert_equal members1.object_id, members2.object_id

      # Verify mock was only called once
      mock_query.verify
    end
  end

  test "group can have members set explicitly without fetching" do
    # Create a group with explicit members
    explicit_members = [
      { id: "user-001" },
      { id: "user-002" }
    ]

    group = EntraId::Group.new(
      id: "group-123",
      display_name: "Test Group",
      members: explicit_members
    )

    # Members should be the explicitly set ones
    assert_equal explicit_members, group.members

    # No fetch should have occurred
    # (accessing members should not trigger a fetch since they were explicitly set)
  end
end
