# frozen_string_literal: true

require_relative "../test_helper"

class UsersControllerTest < Redmine::IntegrationTest
  setup do
    @admin = users(:users_001) # Admin user
    @entra_user = User.generate!(
      oid: "12345-67890-abcde-fghij",
      synced_at: Time.zone.parse("2025-01-15 10:30:00")
    )
    @normal_user = User.generate!
    log_user(@admin.login, "admin")
  end

  test "should display last sync time for entra authenticated users in edit form" do
    get edit_user_path(@entra_user)
    assert_response :success

    # Should display sync time in information fieldset
    assert_select "fieldset legend", text: /Information/i
    assert_select "fieldset", text: /Information/i do
      expected_time = ApplicationController.helpers.format_time(@entra_user.synced_at)
      label = I18n.t(:label_last_entra_id_sync)
      assert_select "p", text: /#{Regexp.escape(label)}.*#{Regexp.escape(expected_time)}/
    end
  end

  test "should not display last sync time for non-entra users in edit form" do
    get edit_user_path(@normal_user)
    assert_response :success

    # Should not display sync time for non-entra users
    assert_select "fieldset", text: /Information/i do
      assert_select "p", text: /#{Regexp.escape(I18n.t(:label_last_entra_id_sync))}/, count: 0
    end
  end
end
