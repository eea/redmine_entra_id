# frozen_string_literal: true

require_relative "../../test_helper"

class User::IdentifiableTest < ActiveSupport::TestCase
  test "user found with case insensitive login matching" do
    user = users(:users_002)  # jsmith
    
    found_by_uppercase_login = User.find_by_login("JSMITH")
    assert_equal user, found_by_uppercase_login

    found_by_mixed_case_login = User.find_by_login("JSmith")
    assert_equal user, found_by_mixed_case_login
  end

  test "user found with case insensitive email matching" do
    user = users(:users_002)  # jsmith@somenet.foo
    
    found_by_uppercase_email = User.find_by_mail("JSMITH@SOMENET.FOO")
    assert_equal user, found_by_uppercase_email

    found_by_mixed_case_email = User.find_by_mail("JSmith@SomeNet.Foo")
    assert_equal user, found_by_mixed_case_email
  end

  test "user found with case insensitive email or login matching" do
    user = users(:users_002)  # jsmith / jsmith@somenet.foo
    
    # Test email matching
    found_by_email = User.find_by_mail("JSMITH@SOMENET.FOO") || User.find_by_login("JSMITH@SOMENET.FOO")
    assert_equal user, found_by_email

    # Test login matching  
    found_by_login = User.find_by_mail("JSMITH") || User.find_by_login("JSMITH")
    assert_equal user, found_by_login
  end

  test "user can be identified by EntraID OID" do
    user = users(:users_002)  # jsmith
    user.update!(oid: "test-oid-123")

    identity = mock("identity")
    identity.stubs(:id).returns("test-oid-123")
    identity.stubs(:preferred_username).returns("other@example.com")

    found_user = User.find_by_identity(identity)
    assert_equal user, found_user
  end

  test "user can be found by email when not having an Entra ID OID" do
    user = users(:users_002)  # jsmith@somenet.foo
    
    identity = mock("identity")
    identity.stubs(:id).returns("non-existent-oid")
    identity.stubs(:preferred_username).returns("jsmith@somenet.foo")

    found_user = User.find_by_identity(identity)
    assert_equal user, found_user
  end

  test "user not found when OID or email don't match" do
    identity = mock("identity")
    identity.stubs(:id).returns("non-existent-oid")
    identity.stubs(:preferred_username).returns("nonexistent@example.com")

    found_user = User.find_by_identity(identity)
    assert_nil found_user
  end

  test "user attributes updated from EntraID while preserving login and mail" do
    user = users(:users_002)  # jsmith
    user.update!(oid: "old-oid")

    identity = mock("identity")
    identity.stubs(:to_user_params).returns({
      login: "newlogin",
      firstname: "NewFirst",
      lastname: "NewLast",
      mail: "new@example.com",
      oid: "new-oid-123",
      synced_at: Time.current
    })

    user.sync_with_identity(identity)

    user.reload

    assert_equal "NewFirst", user.firstname
    assert_equal "NewLast", user.lastname
    assert_equal "new-oid-123", user.oid
    assert_not_nil user.synced_at

    # Should not update login and mail
    assert_equal "jsmith", user.login
    assert_equal "jsmith@somenet.foo", user.mail
  end

  test "user is EntraId authenticated when oid is present" do
    user = users(:users_002)  # jsmith
    user.update!(oid: "test-oid-123")
    assert user.authenticated_via_entra?
  end

  test "user is not EntraId authenticated when oid is blank" do
    user = users(:users_002)  # jsmith
    user.update!(oid: nil)
    refute user.authenticated_via_entra?
  end

  test "user is not EntraId authenticated when oid is empty string" do
    user = users(:users_002)  # jsmith
    user.update!(oid: "")
    refute user.authenticated_via_entra?
  end
end
