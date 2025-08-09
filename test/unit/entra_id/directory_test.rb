require_relative "../../test_helper"

class EntraId::DirectoryTest < ActiveSupport::TestCase
  include EntraIdDirectoryHelper

  setup do
    Setting.plugin_entra_id = {
      enabled: true,
      exclusive: false
    }
  end

  test "returns EntraId::User objects when fetching users from Graph API" do
    # Stub authentication
    stub_request(:post, "https://login.microsoftonline.com/test-tenant-id/oauth2/v2.0/token")
      .to_return(
        status: 200,
        body: { "access_token" => "test-access-token", "expires_in" => 3600 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub Graph API users endpoint with query parameters
    stub_request(:get, /https:\/\/graph\.microsoft\.com\/v1\.0\/users\?/)
      .with(headers: { "Authorization" => "Bearer test-access-token" })
      .to_return(
        status: 200,
        body: {
          "value" => [
            {
              "id" => "12345678-1234-1234-1234-123456789012",
              "mail" => "john.doe@example.com",
              "userPrincipalName" => "john.doe@example.com",
              "givenName" => "John",
              "surname" => "Doe"
            },
            {
              "id" => "87654321-4321-4321-4321-210987654321",
              "mail" => nil,
              "userPrincipalName" => "jane.smith@example.com",
              "givenName" => "Jane",
              "surname" => "Smith"
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    directory = EntraId::Directory.new
    users = directory.users.to_a

    assert_equal 2, users.size

    first_user = users.first
    assert_instance_of EntraId::User, first_user
    assert_equal "12345678-1234-1234-1234-123456789012", first_user.oid
    assert_equal "john.doe@example.com", first_user.email
    assert_equal "John", first_user.given_name
    assert_equal "Doe", first_user.surname

    second_user = users[1]
    assert_equal "jane.smith@example.com", second_user.email  # Should use userPrincipalName
  end

  test "fetches all users across multiple pages when API returns nextLink" do
    # Stub authentication
    stub_request(:post, "https://login.microsoftonline.com/test-tenant-id/oauth2/v2.0/token")
      .to_return(
        status: 200,
        body: { "access_token" => "test-access-token", "expires_in" => 3600 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub first page with query parameters
    stub_request(:get, /https:\/\/graph\.microsoft\.com\/v1\.0\/users\?/)
      .with(headers: { "Authorization" => "Bearer test-access-token" })
      .to_return(
        status: 200,
        body: {
          "value" => [
            {
              "id" => "page1-user1",
              "mail" => "user1@example.com",
              "givenName" => "User",
              "surname" => "One"
            }
          ],
          "@odata.nextLink" => "https://graph.microsoft.com/v1.0/users?$skip=1000"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub second page
    stub_request(:get, "https://graph.microsoft.com/v1.0/users?$skip=1000")
      .with(headers: { "Authorization" => "Bearer test-access-token" })
      .to_return(
        status: 200,
        body: {
          "value" => [
            {
              "id" => "page2-user1",
              "mail" => "user2@example.com",
              "givenName" => "User",
              "surname" => "Two"
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    directory = EntraId::Directory.new
    users = directory.users.to_a

    assert_equal 2, users.size
    assert_equal "page1-user1", users[0].oid
    assert_equal "user1@example.com", users[0].email
    assert_equal "page2-user1", users[1].oid
    assert_equal "user2@example.com", users[1].email
  end

  test "supports batching when iterating through users" do
    # Stub authentication
    stub_request(:post, "https://login.microsoftonline.com/test-tenant-id/oauth2/v2.0/token")
      .to_return(
        status: 200,
        body: { "access_token" => "test-access-token", "expires_in" => 3600 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub Graph API with 5 users with query parameters
    stub_request(:get, /https:\/\/graph\.microsoft\.com\/v1\.0\/users\?/)
      .with(headers: { "Authorization" => "Bearer test-access-token" })
      .to_return(
        status: 200,
        body: {
          "value" => (1..5).map do |i|
            {
              "id" => "user-#{i}",
              "mail" => "user#{i}@example.com",
              "givenName" => "User",
              "surname" => "#{i}"
            }
          end
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    directory = EntraId::Directory.new
    batches = []

    directory.users.each_slice(2) do |batch|
      batches << batch.map(&:oid)
    end

    assert_equal 3, batches.size
    assert_equal [ "user-1", "user-2" ], batches[0]
    assert_equal [ "user-3", "user-4" ], batches[1]
    assert_equal [ "user-5" ], batches[2]
  end

  test "fetches all groups from Microsoft Graph API with member details" do
    # Mock groups response
    groups_response = {
      "value" => [
        {
          "id" => "group-123",
          "displayName" => "Engineering",
          "members@odata.bind" => []
        },
        {
          "id" => "group-456",
          "displayName" => "Marketing",
          "members@odata.bind" => []
        }
      ],
      "@odata.nextLink" => nil
    }

    # Mock transitive members responses for each group
    engineering_members = {
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

    marketing_members = {
      "value" => [
        {
          "id" => "user-003",
          "displayName" => "Bob Johnson",
          "@odata.type" => "#microsoft.graph.user"
        }
      ]
    }

    # Stub the groups endpoint
    stub_request(:get, "https://graph.microsoft.com/v1.0/groups?$select=id,displayName&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: groups_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub the transitive members endpoints
    stub_request(:get, "https://graph.microsoft.com/v1.0/groups/group-123/transitiveMembers?$select=id&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: engineering_members.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://graph.microsoft.com/v1.0/groups/group-456/transitiveMembers?$select=id&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: marketing_members.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    directory = EntraId::Directory.new
    groups = directory.groups

    assert_equal 2, groups.length

    # Check first group
    engineering = groups.find { |g| g.id == "group-123" }
    assert_equal "Engineering", engineering.display_name
    assert_equal 2, engineering.members.length
    assert_equal "user-001", engineering.members[0][:id]

    # Check second group
    marketing = groups.find { |g| g.id == "group-456" }
    assert_equal "Marketing", marketing.display_name
    assert_equal 1, marketing.members.length
    assert_equal "user-003", marketing.members[0][:id]
  end

  test "handles nested group members by always using transitiveMembers" do
    groups_response = {
      "value" => [
        {
          "id" => "parent-group",
          "displayName" => "Parent Group"
        }
      ],
      "@odata.nextLink" => nil
    }

    # Transitive members includes all users from nested groups
    transitive_members = {
      "value" => [
        {
          "id" => "user-001",
          "displayName" => "Direct User",
          "@odata.type" => "#microsoft.graph.user"
        },
        {
          "id" => "user-002",
          "displayName" => "User from Nested Group",
          "@odata.type" => "#microsoft.graph.user"
        },
        {
          "id" => "nested-group",
          "displayName" => "Nested Group",
          "@odata.type" => "#microsoft.graph.group"
        }
      ]
    }

    # Stub the groups endpoint
    stub_request(:get, "https://graph.microsoft.com/v1.0/groups?$select=id,displayName&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: groups_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub the transitive members endpoint
    stub_request(:get, "https://graph.microsoft.com/v1.0/groups/parent-group/transitiveMembers?$select=id&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: transitive_members.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    directory = EntraId::Directory.new
    groups = directory.groups

    assert_equal 1, groups.length
    parent_group = groups.first

    # Should have all transitive members (users only, groups filtered out)
    assert_equal 2, parent_group.members.length
    assert_equal [ "user-001", "user-002" ], parent_group.members.map { |m| m[:id] }.sort
  end

  test "directory builds groups without fetching members" do
    # Mock groups response
    groups_response = {
      "value" => [
        {
          "id" => "group-123",
          "displayName" => "Engineering"
        },
        {
          "id" => "group-456",
          "displayName" => "Marketing"
        }
      ],
      "@odata.nextLink" => nil
    }

    # Stub only the groups endpoint - no member endpoints should be called
    groups_stub = stub_request(:get, "https://graph.microsoft.com/v1.0/groups?$select=id,displayName&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: groups_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Ensure no member endpoints are called during group building
    members_stub = stub_request(:get, /https:\/\/graph\.microsoft\.com\/v1\.0\/groups\/.+\/transitiveMembers/)
      .with(headers: { "Authorization" => "Bearer mock_access_token" })

    directory = EntraId::Directory.new
    groups = directory.groups

    # Verify groups were created
    assert_equal 2, groups.length
    assert_equal "group-123", groups[0].id
    assert_equal "Engineering", groups[0].display_name
    assert_equal "group-456", groups[1].id
    assert_equal "Marketing", groups[1].display_name

    # Verify groups endpoint was called
    assert_requested groups_stub

    # Verify no member endpoints were called
    assert_not_requested members_stub

    # Verify members are not fetched yet
    groups.each do |group|
      assert_nil group.instance_variable_get(:@members)
    end
  end

  test "group members are fetched only when accessed" do
    groups_response = {
      "value" => [
        {
          "id" => "group-123",
          "displayName" => "Engineering"
        }
      ],
      "@odata.nextLink" => nil
    }

    members_response = {
      "value" => [
        {
          "id" => "user-001",
          "displayName" => "John Doe",
          "@odata.type" => "#microsoft.graph.user"
        }
      ]
    }

    # Stub the groups endpoint
    groups_stub = stub_request(:get, "https://graph.microsoft.com/v1.0/groups?$select=id,displayName&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: groups_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub the members endpoint
    members_stub = stub_request(:get, "https://graph.microsoft.com/v1.0/groups/group-123/transitiveMembers?$select=id&$top=999")
      .with(headers: { "Authorization" => "Bearer mock_access_token" })
      .to_return(
        status: 200,
        body: members_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    directory = EntraId::Directory.new
    groups = directory.groups

    # At this point, only groups should have been fetched
    assert_requested groups_stub
    assert_not_requested members_stub

    # Now access members - this should trigger a fetch
    engineering = groups.first
    members = engineering.members

    # Now members should have been fetched
    assert_requested members_stub

    # Verify members data
    assert_equal 1, members.length
    assert_equal "user-001", members[0][:id]
  end
end
