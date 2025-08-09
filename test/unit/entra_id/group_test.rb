require File.expand_path("../../../test_helper", __FILE__)

class EntraId::GroupTest < ActiveSupport::TestCase
  include EntraIdDirectoryHelper

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
        },
        {
          "id" => "nested-group",
          "displayName" => "Nested Group",
          "@odata.type" => "#microsoft.graph.group"
        }
      ]
    }

    # Stub the transitive members endpoint
    stub_request(:get, "https://graph.microsoft.com/v1.0/groups/group-123/transitiveMembers?$select=id&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: members_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    group = EntraId::Group.new(
      id: "group-123",
      display_name: "Test Group"
    )

    # First access should trigger fetch
    members = group.members

    # Should only include users, not groups
    assert_equal 2, members.length
    assert_equal "user-001", members[0][:id]
    assert_equal "user-002", members[1][:id]
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

    # Stub the transitive members endpoint
    members_stub = stub_request(:get, "https://graph.microsoft.com/v1.0/groups/group-123/transitiveMembers?$select=id&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: members_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    group = EntraId::Group.new(
      id: "group-123",
      display_name: "Test Group"
    )

    # First access
    members1 = group.members
    # Second access should use cached value
    members2 = group.members

    # Should be the same object (cached)
    assert_equal members1.object_id, members2.object_id

    # Verify the API was only called once
    assert_requested members_stub, times: 1
  end

  test "group can have members set explicitly without fetching" do
    # Create a group with explicit members
    explicit_members = [
      { id: "user-001" },
      { id: "user-002" }
    ]

    # Ensure no API calls are made
    members_stub = stub_request(:get, /https:\/\/graph\.microsoft\.com\/v1\.0\/groups\/.+\/transitiveMembers/)
      .with(headers: { "Authorization" => "Bearer mock_access_token" })

    group = EntraId::Group.new(
      id: "group-123",
      display_name: "Test Group",
      members: explicit_members
    )

    # Members should be the explicitly set ones
    assert_equal explicit_members, group.members

    # No fetch should have occurred
    assert_not_requested members_stub
  end

  test "group handles empty members response" do
    # Mock empty members response
    empty_response = {
      "value" => []
    }

    # Stub the transitive members endpoint
    stub_request(:get, "https://graph.microsoft.com/v1.0/groups/group-456/transitiveMembers?$select=id&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: empty_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    group = EntraId::Group.new(
      id: "group-456",
      display_name: "Empty Group"
    )

    members = group.members
    assert_equal [], members
  end

  test "group handles pagination when fetching members" do
    # First page of members
    first_page = {
      "value" => [
        {
          "id" => "user-001",
          "displayName" => "User One",
          "@odata.type" => "#microsoft.graph.user"
        }
      ],
      "@odata.nextLink" => "https://graph.microsoft.com/v1.0/groups/group-789/transitiveMembers?$select=id&$top=999&$skiptoken=page2"
    }

    # Second page of members
    second_page = {
      "value" => [
        {
          "id" => "user-002",
          "displayName" => "User Two",
          "@odata.type" => "#microsoft.graph.user"
        }
      ]
    }

    # Stub first page
    stub_request(:get, "https://graph.microsoft.com/v1.0/groups/group-789/transitiveMembers?$select=id&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: first_page.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub second page
    stub_request(:get, "https://graph.microsoft.com/v1.0/groups/group-789/transitiveMembers?$select=id&$top=999&$skiptoken=page2")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: second_page.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    group = EntraId::Group.new(
      id: "group-789",
      display_name: "Large Group"
    )

    members = group.members
    assert_equal 2, members.length
    assert_equal "user-001", members[0][:id]
    assert_equal "user-002", members[1][:id]
  end
end
