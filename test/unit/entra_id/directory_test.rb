require_relative "../../test_helper"

class EntraId::DirectoryTest < ActiveSupport::TestCase
  setup do
    Setting.plugin_entra_id = {
      enabled: true,
      exclusive: false
    }
  end

  test "returns access token when client credentials authentication succeeds" do
    stub_request(:post, "https://login.microsoftonline.com/test-tenant-id/oauth2/v2.0/token")
      .with(
        body: {
          "grant_type" => "client_credentials",
          "client_id" => "test-client-id",
          "client_secret" => "test-secret-123",
          "scope" => "https://graph.microsoft.com/.default"
        }
      )
      .to_return(
        status: 200,
        body: {
          "access_token" => "test-access-token",
          "token_type" => "Bearer",
          "expires_in" => 3600
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    directory = EntraId::Directory.new
    access_token = directory.send(:access_token)  # Private method

    assert_equal "test-access-token", access_token.value
  end

  test "returns EntraId::User objects when fetching users from Graph API" do
    # Stub authentication
    stub_request(:post, "https://login.microsoftonline.com/test-tenant-id/oauth2/v2.0/token")
      .to_return(
        status: 200,
        body: { "access_token" => "test-access-token", "expires_in" => 3600 }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub Graph API users endpoint
    stub_request(:get, "https://graph.microsoft.com/v1.0/users")
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

    # Stub first page
    stub_request(:get, "https://graph.microsoft.com/v1.0/users")
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

    # Stub Graph API with 5 users
    stub_request(:get, "https://graph.microsoft.com/v1.0/users")
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
end
