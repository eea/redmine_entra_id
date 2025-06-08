# frozen_string_literal: true

require_relative "../../test_helper"

class EntraId::CallbacksControllerTest < Redmine::IntegrationTest
  include OauthTestHelper

  test "user data gets synced from EntraId on login" do
    user = users(:users_002)
    user.update!(oid: "test-oid-123", firstname: "OldFirstName", lastname: "OldLastName")

    with_settings plugin_entra_id: {
      "enabled" => true,
      "client_id" => "test-client-id",
      "client_secret" => "test-client-secret",
      "tenant_id" => "test-tenant-id"
      } do
      # Start OAuth flow by calling the authorization endpoint
      get new_entra_id_authorization_path

      # Extract the authorization code from session to stub the callback
      authorization_code = "test-code"
      stub_full_oauth_flow(
        code: authorization_code,
        user_data: {
          id: "test-oid-123",
          givenName: "NewFirstName",
          surname: "NewLastName",
          mail: user.mail
        }
      )

      # Simulate the callback from EntraId
      get entra_id_callback_path, params: {
        code: authorization_code,
        state: session[:entra_id_state]
      }

      user.reload

      assert_equal "NewFirstName", user.firstname
      assert_equal "NewLastName", user.lastname
      assert_equal "test-oid-123", user.oid
      assert_not_nil user.synced_at
    end
  end
end
