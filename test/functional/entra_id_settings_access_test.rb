# frozen_string_literal: true

require "test_helper"

class EntraIdSettingsAccessTest < ActionController::TestCase
  tests SettingsController

  def setup
    super
    @original_settings = Setting.plugin_entra_id.dup
    Setting.plugin_entra_id = {
      "enabled" => true,
      "client_id" => "test-client-id",
      "client_secret" => "test-secret",
      "tenant_id" => "test-tenant-id"
    }
  end

  def teardown
    Setting.plugin_entra_id = @original_settings
  end

  test "admin user can access plugin settings page" do
    admin_user = User.find(1) # User 1 is admin by default in test fixtures
    User.current = admin_user
    @request.session[:user_id] = admin_user.id

    get :plugin, params: { id: "entra_id" }

    assert_response :success
    assert_select "form[action*='plugin']"
  end

  test "admin user can update plugin settings" do
    admin_user = User.find(1)
    User.current = admin_user
    @request.session[:user_id] = admin_user.id

    post :plugin, params: {
      id: "entra_id",
      settings: {
        enabled: false,
        client_id: "updated-client-id"
      }
    }

    assert_response :redirect
    assert_equal "updated-client-id", Setting.plugin_entra_id["client_id"]
  end

  test "regular user cannot access plugin settings page" do
    regular_user = User.find(2) # User 2 is regular user
    User.current = regular_user
    @request.session[:user_id] = regular_user.id

    get :plugin, params: { id: "entra_id" }

    assert_response :forbidden
  end

  test "regular user cannot update plugin settings" do
    regular_user = User.find(2)
    User.current = regular_user
    @request.session[:user_id] = regular_user.id

    post :plugin, params: {
      id: "entra_id",
      settings: {
        enabled: false,
        client_id: "hacker-attempt"
      }
    }

    assert_response :forbidden
    # Settings should remain unchanged
    assert_equal "test-client-id", Setting.plugin_entra_id["client_id"]
  end

  test "unauthenticated user cannot access plugin settings page" do
    User.current = nil
    @request.session.delete(:user_id)

    get :plugin, params: { id: "entra_id" }

    assert_response :redirect
    assert_match %r{/login}, response.location
  end

  test "unauthenticated user cannot update plugin settings" do
    User.current = nil
    @request.session.delete(:user_id)

    post :plugin, params: {
      id: "entra_id",
      settings: {
        enabled: false,
        client_id: "unauthenticated-attempt"
      }
    }

    assert_response :redirect
    assert_match %r{/login}, response.location
    # Settings should remain unchanged
    assert_equal "test-client-id", Setting.plugin_entra_id["client_id"]
  end

  test "anonymous user cannot access plugin settings page" do
    User.current = User.anonymous
    @request.session.delete(:user_id)

    get :plugin, params: { id: "entra_id" }

    assert_response :redirect
    assert_match %r{/login}, response.location
  end
end
