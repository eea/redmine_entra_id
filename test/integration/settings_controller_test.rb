# frozen_string_literal: true

require_relative "../test_helper"

class SettingsControllerTest < Redmine::IntegrationTest
  setup do
    Setting.plugin_entra_id = {
      "enabled" => true
    }.with_indifferent_access
  end

  test "unauthenticated user cannot access plugin settings page" do
    get plugin_settings_path("entra_id")
    assert_response :redirect
    assert_redirected_to signin_path(back_url: plugin_settings_url("entra_id"))
  end

  test "regular user cannot access plugin settings page" do
    log_user("jsmith", "jsmith")
    
    get plugin_settings_path("entra_id")
    assert_response :forbidden
  end

  test "only admin user can access plugin settings page" do
    log_user("admin", "admin")
    
    get plugin_settings_path("entra_id")
    assert_response :success
  end

  test "admin can see environment variable values" do
    log_user("admin", "admin")
    
    get plugin_settings_path("entra_id")
    assert_response :success
    
    # Check that the env var values are displayed
    assert_select "strong", text: "test-client-id"
    assert_select "strong", text: "tes******************"
    assert_select "strong", text: "test-tenant-id"
    
    # Check that the env var note is displayed
    assert_select "div.info" do
      assert_select "code", text: "ENTRA_ID_CLIENT_ID"
      assert_select "code", text: "ENTRA_ID_CLIENT_SECRET"
      assert_select "code", text: "ENTRA_ID_TENANT_ID"
    end
  end
end