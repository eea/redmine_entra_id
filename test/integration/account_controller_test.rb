# frozen_string_literal: true

require_relative "../test_helper"

class AccountControllerTest < Redmine::IntegrationTest
  test "plugin disabled no entra id button appears" do
    with_settings plugin_entra_id: { enabled: false }, login_required: false do
      get signin_path
      
      assert_response :success
      assert_select "#entra-id-form", count: 0
      assert_select "button", text: "Log in with EEA Microsoft Entra ID", count: 0
      assert_select "#login-form", count: 1
      assert_select "input#username", count: 1
      assert_select "input#password", count: 1
    end
  end

  test "plugin enabled entra id button and regular form appear" do
    with_settings plugin_entra_id: { enabled: true, exclusive: false }, login_required: false do
      get signin_path

      assert_response :success
      assert_select "#entra-id-form", count: 1
      assert_select "button", text: "Log in with EEA Microsoft Entra ID", count: 1
      assert_select "#login-form", count: 1
      assert_select "input#username", count: 1
      assert_select "input#password", count: 1
    end
  end

  test "plugin enabled and exclusive only entra id button appears" do
    with_settings plugin_entra_id: { enabled: true, exclusive: true }, login_required: false do
      get signin_path

      assert_response :success
      assert_select "#entra-id-form", count: 1
      assert_select "button", text: "Log in with EEA Microsoft Entra ID", count: 1
      assert_select "#login-form", count: 0
      assert_select "input#username", count: 0
      assert_select "input#password", count: 0
    end
  end
end
