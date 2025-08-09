require_relative "../../test_helper"

class EntraId::IdentityTest < ActiveSupport::TestCase
  include OauthTestHelper

  test "handles nil givenName and surname from Graph API response" do
    stub_oauth_user_info(
      access_token: "mock_token",
      user_data: {
        id: "12345678-1234-1234-1234-123456789012",
        displayName: "John A. Doe",
        givenName: nil,
        surname: nil,
        mail: nil,
        userPrincipalName: "john.doe@example.com"
      }
    )

    identity = EntraId::Identity.new(
      claims: { "oid" => "12345678-1234-1234-1234-123456789012", "preferred_username" => "john.doe@example.com" },
      access_token: "mock_token"
    )

    assert_equal "John", identity.first_name
    assert_equal "A. Doe", identity.last_name

    user_params = identity.to_user_params
    assert_equal "John", user_params[:firstname]
    assert_equal "A. Doe", user_params[:lastname]
  end
end
