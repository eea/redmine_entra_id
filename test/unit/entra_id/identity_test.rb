require_relative "../../test_helper"

class EntraId::IdentityTest < ActiveSupport::TestCase
  test "handles nil givenName and surname from Graph API response" do
    # This simulates the actual response from the Graph API where
    # givenName and surname are explicitly nil
    user_info_response = {
      "@odata.context" => "https://graph.microsoft.com/v1.0/$metadata#users/$entity",
      "businessPhones" => [],
      "displayName" => "John A. Doe",
      "givenName" => nil,
      "jobTitle" => nil,
      "mail" => nil,
      "mobilePhone" => nil,
      "officeLocation" => nil,
      "preferredLanguage" => nil,
      "surname" => nil,
      "userPrincipalName" => "john.doe@example.com",
      "id" => "12345678-1234-1234-1234-123456789012"
    }

    identity = EntraId::Identity.new(
      claims: {"oid" => "12345678-1234-1234-1234-123456789012", "preferred_username" => "john.doe@example.com"},
      access_token: "mock_token"
    )
    
    # Mock the fetch_user_info method to return our test data
    identity.define_singleton_method(:fetch_user_info) do
      user_info_response
    end

    # Test that it correctly parses displayName when givenName/surname are nil
    assert_equal "John", identity.first_name
    assert_equal "A. Doe", identity.last_name
    
    # Test the to_user_params method works correctly
    user_params = identity.to_user_params
    assert_equal "John", user_params[:firstname]
    assert_equal "A. Doe", user_params[:lastname]
  end
end