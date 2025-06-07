# frozen_string_literal: true

require "test_helper"

class EmailAddress::IdentifiableTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      login: "testuser",
      firstname: "Test",
      lastname: "User",
      mail: "testuser@example.com",
      status: User::STATUS_ACTIVE
    )
    @email_address = @user.email_addresses.first
  end

  test "email address found with case insensitive address matching" do
    found_by_uppercase = EmailAddress.by_address("TESTUSER@EXAMPLE.COM").first
    assert_equal @email_address, found_by_uppercase

    found_by_mixed_case = EmailAddress.by_address("TestUser@Example.Com").first
    assert_equal @email_address, found_by_mixed_case
  end
end
