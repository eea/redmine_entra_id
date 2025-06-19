# frozen_string_literal: true

require_relative "../../test_helper"

class EntraId::AccountReconcilerTest < ActiveSupport::TestCase
  include EntraIdDirectoryHelper

  setup do
    @reconciler = EntraId::AccountReconciler.new
  end

  test "reconciler creates new user when entra user doesn't exist locally" do
    expected_oid = "aaaa-bbbb-cccc-1234"
    expected_email = "john.doe@example.com"
    expected_first_name = "John"
    expected_last_name = "Doe"
    
    setup_entra_users([
      {
        oid: expected_oid,
        email: expected_email,
        given_name: expected_first_name,
        surname: expected_last_name
      }
    ])

    @reconciler.reconcile
    new_user = User.find_by(oid: expected_oid)

    assert_not_nil new_user

    assert_equal expected_email, new_user.login
    assert_equal expected_email, new_user.mail
    assert_equal expected_first_name, new_user.firstname
    assert_equal expected_last_name, new_user.lastname
  end

  test "reconciler updates existing user when found by oid" do
    existing_user = User.find_by(login: "jsmith")
    existing_oid = "existing-jsmith-123"
    existing_user.update!(oid: existing_oid, synced_at: 1.hour.ago)
    
    updated_email = "john.smith.updated@example.com"
    updated_first_name = "Johnny"
    updated_last_name = "Smith"
    
    setup_entra_users([
      {
        oid: existing_oid,
        email: updated_email,
        given_name: updated_first_name,
        surname: updated_last_name
      }
    ])
    
    @reconciler.reconcile
    existing_user.reload

    assert_equal updated_email, existing_user.mail
    assert_equal updated_first_name, existing_user.firstname
    assert_equal updated_last_name, existing_user.lastname
    assert_not_nil existing_user.synced_at
  end




end
