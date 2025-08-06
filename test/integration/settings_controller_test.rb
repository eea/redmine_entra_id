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
    
    assert_select "p" do
      assert_select "code", text: "test-client-id"
      assert_select "em.info", text: "Set via ENTRA_ID_CLIENT_ID environment variable"
    end
    
    assert_select "p" do
      assert_select "code", text: "tes******************"
      assert_select "em.info", text: "Set via ENTRA_ID_CLIENT_SECRET environment variable"
    end
    
    assert_select "p" do
      assert_select "code", text: "test-tenant-id"
      assert_select "em.info", text: "Set via ENTRA_ID_TENANT_ID environment variable"
    end
  end
end