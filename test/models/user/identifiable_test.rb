# frozen_string_literal: true

require "test_helper"

class User::IdentifiableTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      login: "testuser",
      firstname: "Test",
      lastname: "User",
      mail: "testuser@example.com",
      status: User::STATUS_ACTIVE
    )
  end

  test "user found with case insensitive login matching" do
    found_by_uppercase_login = User.by_login("TESTUSER").first
    assert_equal @user, found_by_uppercase_login

    found_by_mixed_case_login = User.by_login("TestUser").first
    assert_equal @user, found_by_mixed_case_login
  end

  test "user found with case insensitive email matching" do
    found_by_uppercase_email = User.by_email("TESTUSER@EXAMPLE.COM").first
    assert_equal @user, found_by_uppercase_email

    found_by_mixed_case_email = User.by_email("TestUser@Example.Com").first
    assert_equal @user, found_by_mixed_case_email
  end

  test "user found with case insensitive email or login matching" do
    found_by_email_or_login_uppercase = User.by_email_or_login("TESTUSER@EXAMPLE.COM").first
    assert_equal @user, found_by_email_or_login_uppercase

    found_by_email_or_login_login_case = User.by_email_or_login("TESTUSER").first
    assert_equal @user, found_by_email_or_login_login_case
  end

  test "user can be identified by EntraID OID" do
    @user.update!(oid: "test-oid-123")

    identity = mock("identity")
    identity.stubs(:id).returns("test-oid-123")
    identity.stubs(:preferred_username).returns("other@example.com")

    found_user = User.find_by_identity(identity)
    assert_equal @user, found_user
  end

  test "user can be found by email when not having an Entra ID OID" do
    identity = mock("identity")
    identity.stubs(:id).returns("non-existent-oid")
    identity.stubs(:preferred_username).returns("testuser@example.com")

    found_user = User.find_by_identity(identity)
    assert_equal @user, found_user
  end

  test "user not found when OID or email don't match" do
    identity = mock("identity")
    identity.stubs(:id).returns("non-existent-oid")
    identity.stubs(:preferred_username).returns("nonexistent@example.com")

    found_user = User.find_by_identity(identity)
    assert_nil found_user
  end

  test "user attributes updated from EntraID while preserving login and mail" do
    @user.update!(oid: "old-oid")

    identity = mock("identity")
    identity.stubs(:to_user_params).returns({
      login: "newlogin",
      firstname: "NewFirst",
      lastname: "NewLast",
      mail: "new@example.com",
      oid: "new-oid-123",
      synced_at: Time.current
    })

    @user.sync_with_identity(identity)

    @user.reload

    assert_equal "NewFirst", @user.firstname
    assert_equal "NewLast", @user.lastname
    assert_equal "new-oid-123", @user.oid
    assert_not_nil @user.synced_at

    # Should not update login and mail
    assert_equal "testuser", @user.login
    assert_equal "testuser@example.com", @user.mail
  end
end
