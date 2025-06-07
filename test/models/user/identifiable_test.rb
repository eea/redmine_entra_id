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
end
