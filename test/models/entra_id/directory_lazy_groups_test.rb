require File.expand_path("../../../test_helper", __FILE__)
require "minitest/mock"

class EntraId::DirectoryLazyGroupsTest < ActiveSupport::TestCase
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

    directory = EntraId::Directory.new

    # The fetch_page method should only be called once for groups
    # and NOT for member fetching
    call_count = 0
    directory.stub :fetch_page, ->(url) {
      call_count += 1

      case url
      when "https://graph.microsoft.com/v1.0/groups?$select=id,displayName&$top=999"
        groups_response
      else
        # This should not happen during group building
        raise "Unexpected URL during group building: #{url}"
      end
    } do
      groups = directory.groups

      # Verify groups were created
      assert_equal 2, groups.length
      assert_equal "group-123", groups[0].id
      assert_equal "Engineering", groups[0].display_name
      assert_equal "group-456", groups[1].id
      assert_equal "Marketing", groups[1].display_name

      # Verify fetch_page was only called once (for groups)
      assert_equal 1, call_count

      # Verify members are not fetched yet
      groups.each do |group|
        assert_nil group.instance_variable_get(:@members)
      end
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

    directory = EntraId::Directory.new

    fetch_urls = []
    directory.stub :fetch_page, ->(url) {
      fetch_urls << url

      case url
      when "https://graph.microsoft.com/v1.0/groups?$select=id,displayName&$top=999"
        groups_response
      when "https://graph.microsoft.com/v1.0/groups/group-123/transitiveMembers?$select=id&$top=999"
        members_response
      else
        raise "Unexpected URL: #{url}"
      end
    } do
      groups = directory.groups

      # At this point, only groups should have been fetched
      assert_equal 1, fetch_urls.length
      assert_includes fetch_urls[0], "/groups?"

      # Now access members - this should trigger a fetch
      engineering = groups.first
      members = engineering.members

      # Now members should have been fetched
      assert_equal 2, fetch_urls.length
      assert_includes fetch_urls[1], "/transitiveMembers"

      # Verify members data
      assert_equal 1, members.length
      assert_equal "user-001", members[0][:id]
    end
  end
end
