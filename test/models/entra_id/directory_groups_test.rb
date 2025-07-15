require File.expand_path('../../../test_helper', __FILE__)
require 'minitest/mock'

class EntraId::DirectoryGroupsTest < ActiveSupport::TestCase
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
    
    # Mock members responses for each group
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
    
    
    directory = EntraId::Directory.new
    directory.stub :fetch_page, ->(url) {
      case url
      when "https://graph.microsoft.com/v1.0/groups?$select=id,displayName&$top=100"
        groups_response
      when "https://graph.microsoft.com/v1.0/groups/group-123/members?$select=id,displayName&$top=999"
        engineering_members
      when "https://graph.microsoft.com/v1.0/groups/group-456/members?$select=id,displayName&$top=999"
        marketing_members
      else
        raise "Unexpected URL: #{url}"
      end
    } do
      groups = directory.groups
      
      assert_equal 2, groups.length
      
      # Check first group
      engineering = groups.find { |g| g.id == "group-123" }
      assert_equal "Engineering", engineering.display_name
      assert_equal 2, engineering.members.length
      assert_equal "user-001", engineering.members[0][:id]
      assert_equal "John Doe", engineering.members[0][:display_name]
      
      # Check second group
      marketing = groups.find { |g| g.id == "group-456" }
      assert_equal "Marketing", marketing.display_name
      assert_equal 1, marketing.members.length
      assert_equal "user-003", marketing.members[0][:id]
    end
    
  end
  
  test "handles nested group members by fetching transitiveMembers" do
    groups_response = {
      "value" => [
        {
          "id" => "parent-group",
          "displayName" => "Parent Group"
        }
      ],
      "@odata.nextLink" => nil
    }
    
    # Members includes both users and nested groups
    direct_members = {
      "value" => [
        {
          "id" => "user-001",
          "displayName" => "Direct User",
          "@odata.type" => "#microsoft.graph.user"
        },
        {
          "id" => "nested-group",
          "displayName" => "Nested Group",
          "@odata.type" => "#microsoft.graph.group"
        }
      ]
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
        }
      ]
    }
    
    directory = EntraId::Directory.new
    directory.stub :fetch_page, ->(url) {
      case url
      when "https://graph.microsoft.com/v1.0/groups?$select=id,displayName&$top=100"
        groups_response
      when "https://graph.microsoft.com/v1.0/groups/parent-group/members?$select=id,displayName&$top=999"
        direct_members
      when "https://graph.microsoft.com/v1.0/groups/parent-group/transitiveMembers?$select=id,displayName&$top=999"
        transitive_members
      else
        raise "Unexpected URL: #{url}"
      end
    } do
      groups = directory.groups
      
      assert_equal 1, groups.length
      parent_group = groups.first
      
      # Should have all transitive members (users only)
      assert_equal 2, parent_group.members.length
      assert_equal ["user-001", "user-002"], parent_group.members.map { |m| m[:id] }.sort
    end
    
  end
end