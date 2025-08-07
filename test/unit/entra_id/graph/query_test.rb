require_relative "../../../test_helper"

class EntraId::Graph::QueryTest < ActiveSupport::TestCase
  def setup
    @query = EntraId::Graph::Query.new
    @access_token_mock = mock("access_token")
    @access_token_mock.stubs(:value).returns("test_token")
    EntraId::Directory::AccessToken.stubs(:new).returns(@access_token_mock)
  end

  test "fetches all users across multiple pages" do
    # First page response
    first_page_response = {
      "value" => [
        {
          "id" => "user1",
          "userPrincipalName" => "user1@example.com",
          "mail" => "user1@example.com",
          "givenName" => "User",
          "surname" => "One",
          "displayName" => "User One"
        },
        {
          "id" => "user2",
          "userPrincipalName" => "user2@example.com",
          "mail" => "user2@example.com",
          "givenName" => "User",
          "surname" => "Two",
          "displayName" => "User Two"
        }
      ],
      "@odata.nextLink" => "https://graph.microsoft.com/v1.0/users?$skiptoken=page2"
    }

    # Second page response
    second_page_response = {
      "value" => [
        {
          "id" => "user3",
          "userPrincipalName" => "user3@example.com",
          "mail" => "user3@example.com",
          "givenName" => "User",
          "surname" => "Three",
          "displayName" => "User Three"
        }
      ],
      "@odata.nextLink" => "https://graph.microsoft.com/v1.0/users?$skiptoken=page3"
    }

    # Third (final) page response - no nextLink
    third_page_response = {
      "value" => [
        {
          "id" => "user4",
          "userPrincipalName" => "user4@example.com",
          "mail" => "user4@example.com",
          "givenName" => "User",
          "surname" => "Four",
          "displayName" => "User Four"
        }
      ]
    }

    # Mock HTTP responses
    http_client_mock = mock("http_client")
    EntraId::HttpClient.stubs(:new).returns(http_client_mock)

    # Create response mocks
    first_response = mock("first_response")
    first_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    first_response.stubs(:body).returns(first_page_response.to_json)

    second_response = mock("second_response")
    second_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    second_response.stubs(:body).returns(second_page_response.to_json)

    third_response = mock("third_response")
    third_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    third_response.stubs(:body).returns(third_page_response.to_json)

    # Set up expectations for each page request
    http_client_mock.expects(:get).with(
      includes("users") && includes("$select=id,userPrincipalName,mail,givenName,surname,displayName"),
      has_entry("Authorization", "Bearer test_token")
    ).returns(first_response)

    http_client_mock.expects(:get).with(
      includes("$skiptoken=page2"),
      has_entry("Authorization", "Bearer test_token")
    ).returns(second_response)

    http_client_mock.expects(:get).with(
      includes("$skiptoken=page3"),
      has_entry("Authorization", "Bearer test_token")
    ).returns(third_response)

    # Execute
    users = @query.users

    # Verify all users were collected
    assert_equal 4, users.length
    assert_equal "user1", users[0]["id"]
    assert_equal "user2@example.com", users[1]["userPrincipalName"]
    assert_equal "User Three", users[2]["displayName"]
    assert_equal "user4@example.com", users[3]["mail"]
  end

  test "fetches all groups across multiple pages" do
    # First page response
    first_page_response = {
      "value" => [
        {
          "id" => "group1",
          "displayName" => "Engineering Team"
        },
        {
          "id" => "group2",
          "displayName" => "Marketing Team"
        },
        {
          "id" => "group3",
          "displayName" => "Sales Team"
        }
      ],
      "@odata.nextLink" => "https://graph.microsoft.com/v1.0/groups?$skiptoken=page2"
    }

    # Second page response
    second_page_response = {
      "value" => [
        {
          "id" => "group4",
          "displayName" => "HR Team"
        },
        {
          "id" => "group5",
          "displayName" => "Finance Team"
        }
      ],
      "@odata.nextLink" => "https://graph.microsoft.com/v1.0/groups?$skiptoken=page3"
    }

    # Third (final) page response - no nextLink
    third_page_response = {
      "value" => [
        {
          "id" => "group6",
          "displayName" => "Executive Team"
        }
      ]
    }

    # Mock HTTP responses
    http_client_mock = mock("http_client")
    EntraId::HttpClient.stubs(:new).returns(http_client_mock)

    # Create response mocks
    first_response = mock("first_response")
    first_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    first_response.stubs(:body).returns(first_page_response.to_json)

    second_response = mock("second_response")
    second_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    second_response.stubs(:body).returns(second_page_response.to_json)

    third_response = mock("third_response")
    third_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    third_response.stubs(:body).returns(third_page_response.to_json)

    # Set up expectations for each page request
    http_client_mock.expects(:get).with(
      includes("groups") && includes("$select=id,displayName"),
      has_entry("Authorization", "Bearer test_token")
    ).returns(first_response)

    http_client_mock.expects(:get).with(
      includes("$skiptoken=page2"),
      has_entry("Authorization", "Bearer test_token")
    ).returns(second_response)

    http_client_mock.expects(:get).with(
      includes("$skiptoken=page3"),
      has_entry("Authorization", "Bearer test_token")
    ).returns(third_response)

    # Execute
    groups = @query.groups

    # Verify all groups were collected
    assert_equal 6, groups.length
    assert_equal "group1", groups[0]["id"]
    assert_equal "Marketing Team", groups[1]["displayName"]
    assert_equal "Sales Team", groups[2]["displayName"]
    assert_equal "group4", groups[3]["id"]
    assert_equal "Finance Team", groups[4]["displayName"]
    assert_equal "Executive Team", groups[5]["displayName"]
  end

  test "handles empty pages correctly during pagination" do
    # First page with data
    first_page_response = {
      "value" => [
        { "id" => "user1", "displayName" => "User One" }
      ],
      "@odata.nextLink" => "https://graph.microsoft.com/v1.0/users?$skiptoken=page2"
    }

    # Second page empty but with nextLink
    second_page_response = {
      "value" => [],
      "@odata.nextLink" => "https://graph.microsoft.com/v1.0/users?$skiptoken=page3"
    }

    # Third page with data
    third_page_response = {
      "value" => [
        { "id" => "user2", "displayName" => "User Two" }
      ]
    }

    # Mock HTTP responses
    http_client_mock = mock("http_client")
    EntraId::HttpClient.stubs(:new).returns(http_client_mock)

    first_response = mock("first_response")
    first_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    first_response.stubs(:body).returns(first_page_response.to_json)

    second_response = mock("second_response")
    second_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    second_response.stubs(:body).returns(second_page_response.to_json)

    third_response = mock("third_response")
    third_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    third_response.stubs(:body).returns(third_page_response.to_json)

    http_client_mock.expects(:get).times(3).returns(first_response, second_response, third_response)

    # Execute
    users = @query.users

    # Verify correct handling of empty page
    assert_equal 2, users.length
    assert_equal "user1", users[0]["id"]
    assert_equal "user2", users[1]["id"]
  end

  test "handles single page response without pagination" do
    # Single page response without nextLink
    single_page_response = {
      "value" => [
        { "id" => "group1", "displayName" => "Team A" },
        { "id" => "group2", "displayName" => "Team B" }
      ]
    }

    # Mock HTTP response
    http_client_mock = mock("http_client")
    EntraId::HttpClient.stubs(:new).returns(http_client_mock)

    response = mock("response")
    response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    response.stubs(:body).returns(single_page_response.to_json)

    http_client_mock.expects(:get).once.returns(response)

    # Execute
    groups = @query.groups

    # Verify single page was handled correctly
    assert_equal 2, groups.length
    assert_equal "group1", groups[0]["id"]
    assert_equal "Team B", groups[1]["displayName"]
  end

  test "fetches group transitive members with pagination" do
    group_id = "test-group-123"

    # First page response with mixed member types
    first_page_response = {
      "value" => [
        {
          "id" => "user1",
          "@odata.type" => "#microsoft.graph.user",
          "userPrincipalName" => "user1@example.com"
        },
        {
          "id" => "nested-group1",
          "@odata.type" => "#microsoft.graph.group",
          "displayName" => "Nested Group"
        },
        {
          "id" => "user2",
          "@odata.type" => "#microsoft.graph.user",
          "userPrincipalName" => "user2@example.com"
        }
      ],
      "@odata.nextLink" => "https://graph.microsoft.com/v1.0/groups/#{group_id}/transitiveMembers?$skiptoken=page2"
    }

    # Second page response
    second_page_response = {
      "value" => [
        {
          "id" => "user3",
          "@odata.type" => "#microsoft.graph.user",
          "userPrincipalName" => "user3@example.com"
        },
        {
          "id" => "nested-group2",
          "@odata.type" => "#microsoft.graph.group",
          "displayName" => "Another Nested Group"
        }
      ]
    }

    # Mock HTTP responses
    http_client_mock = mock("http_client")
    EntraId::HttpClient.stubs(:new).returns(http_client_mock)

    first_response = mock("first_response")
    first_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    first_response.stubs(:body).returns(first_page_response.to_json)

    second_response = mock("second_response")
    second_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    second_response.stubs(:body).returns(second_page_response.to_json)

    http_client_mock.expects(:get).with(
      includes("groups/#{group_id}/transitiveMembers"),
      has_entry("Authorization", "Bearer test_token")
    ).returns(first_response)

    http_client_mock.expects(:get).with(
      includes("$skiptoken=page2"),
      has_entry("Authorization", "Bearer test_token")
    ).returns(second_response)

    # Execute
    members = @query.group_transitive_members(group_id)

    # Verify only users are returned (groups filtered out)
    assert_equal 3, members.length
    assert_equal "user1", members[0]["id"]
    assert_equal "user2", members[1]["id"]
    assert_equal "user3", members[2]["id"]

    # Verify groups were filtered out
    assert members.none? { |m| m["id"].include?("nested-group") }
  end

  test "handles API errors during pagination" do
    # Mock HTTP client
    http_client_mock = mock("http_client")
    EntraId::HttpClient.stubs(:new).returns(http_client_mock)

    # Create error response
    error_response = mock("error_response")
    error_response.stubs(:is_a?).with(Net::HTTPSuccess).returns(false)
    error_response.stubs(:code).returns("429")
    error_response.stubs(:body).returns('{"error": "Too Many Requests"}')

    http_client_mock.expects(:get).returns(error_response)

    # Execute and verify error handling
    assert_raises(EntraId::NetworkError) do
      @query.users
    end
  end

  test "handles JSON parsing errors" do
    # Mock HTTP client
    http_client_mock = mock("http_client")
    EntraId::HttpClient.stubs(:new).returns(http_client_mock)

    # Create response with invalid JSON
    response = mock("response")
    response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    response.stubs(:body).returns("Invalid JSON {")

    http_client_mock.expects(:get).returns(response)

    # Execute and verify error handling
    assert_raises(EntraId::NetworkError) do
      @query.groups
    end
  end

  test "respects MAX_PAGE_SIZE in URL construction" do
    expected_page_size = EntraId::Graph::Query::MAX_PAGE_SIZE

    users_url = EntraId::Graph::Query.users_url
    assert_includes users_url, "$top=#{expected_page_size}"

    groups_url = EntraId::Graph::Query.groups_url
    assert_includes groups_url, "$top=#{expected_page_size}"

    group_members_url = EntraId::Graph::Query.group_members_url("test-group")
    assert_includes group_members_url, "$top=#{expected_page_size}"
  end

  test "constructs correct URLs with custom select fields" do
    users_url = EntraId::Graph::Query.users_url(select: [ "id", "mail", "displayName" ])
    assert_includes users_url, "$select=id,mail,displayName"

    groups_url = EntraId::Graph::Query.groups_url(select: [ "id", "description" ])
    assert_includes groups_url, "$select=id,description"
  end
end
