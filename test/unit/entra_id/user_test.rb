require_relative "../../test_helper"

class EntraId::UserTest < ActiveSupport::TestCase
  test "user creation with valid EntraId data" do
    entra_user = EntraId::User.new({
      id: "12345678-1234-1234-1234-123456789012",
      userPrincipalName: "john.doe@example.com",
      mail: "john.doe@example.com",
      givenName: "John",
      surname: "Doe"
    }.with_indifferent_access)

    assert_difference "User.count", 1 do
      result = entra_user.replicate_locally!
      assert_equal true, result
    end

    user = User.find_by(login: "john.doe@example.com")

    assert_not_nil user
    assert_equal "john.doe@example.com", user.login
    assert_equal "John", user.firstname
    assert_equal "Doe", user.lastname
    assert_equal "john.doe@example.com", user.mail
    assert_equal "12345678-1234-1234-1234-123456789012", user.oid
    assert_not_nil user.synced_at
  end

  test "user update when found by OID match" do
    existing_user = User.create!(
      login: "old.email@example.com",
      firstname: "OldFirst",
      lastname: "OldLast",
      mail: "old.email@example.com",
      oid: "12345678-1234-1234-1234-123456789012"
    )

    entra_user = EntraId::User.new({
      id: "12345678-1234-1234-1234-123456789012",
      userPrincipalName: "new.email@example.com",
      mail: "new.email@example.com",
      givenName: "NewFirst",
      surname: "NewLast"
    }.with_indifferent_access)

    assert_no_difference "User.count" do
      result = entra_user.replicate_locally!
      assert_equal true, result
    end

    existing_user.reload
    assert_equal "old.email@example.com", existing_user.login
    assert_equal "NewFirst", existing_user.firstname
    assert_equal "NewLast", existing_user.lastname
    assert_equal "new.email@example.com", existing_user.mail
    assert_equal "12345678-1234-1234-1234-123456789012", existing_user.oid
    assert_not_nil existing_user.synced_at
  end

  test "user update when found by email match" do
    existing_user = User.create!(
      login: "john.doe@example.com",
      firstname: "OldFirst",
      lastname: "OldLast",
      mail: "john.doe@example.com"
    )

    entra_user = EntraId::User.new({
      id: "12345678-1234-1234-1234-123456789012",
      userPrincipalName: "john.doe@example.com",
      mail: "john.doe@example.com",
      givenName: "NewFirst",
      surname: "NewLast"
    }.with_indifferent_access)

    assert_no_difference "User.count" do
      result = entra_user.replicate_locally!
      assert_equal true, result
    end

    existing_user.reload
    assert_equal "john.doe@example.com", existing_user.login
    assert_equal "NewFirst", existing_user.firstname
    assert_equal "NewLast", existing_user.lastname
    assert_equal "john.doe@example.com", existing_user.mail
    assert_equal "12345678-1234-1234-1234-123456789012", existing_user.oid
    assert_not_nil existing_user.synced_at
  end

  test "user update when found by login match" do
    existing_user = User.create!(
      login: "john.doe@example.com",
      firstname: "OldFirst",
      lastname: "OldLast",
      mail: "different.email@example.com"
    )

    entra_user = EntraId::User.new({
      id: "12345678-1234-1234-1234-123456789012",
      userPrincipalName: "john.doe@example.com",
      mail: "john.doe@example.com",
      givenName: "NewFirst",
      surname: "NewLast"
    }.with_indifferent_access)

    assert_no_difference "User.count" do
      result = entra_user.replicate_locally!
      assert_equal true, result
    end

    existing_user.reload
    assert_equal "john.doe@example.com", existing_user.login
    assert_equal "NewFirst", existing_user.firstname
    assert_equal "NewLast", existing_user.lastname
    assert_equal "john.doe@example.com", existing_user.mail
    assert_equal "12345678-1234-1234-1234-123456789012", existing_user.oid
    assert_not_nil existing_user.synced_at
  end

  test "updates all user attributes from EntraId" do
    existing_user = User.create!(
      login: "user@example.com",
      firstname: "OldFirstName",
      lastname: "OldLastName",
      mail: "user@example.com",
      oid: "old-oid-12345"
    )

    entra_user = EntraId::User.new({
      id: "old-oid-12345",
      userPrincipalName: "user@example.com",
      mail: "user@example.com",
      givenName: "NewGivenName",
      surname: "NewSurname"
    }.with_indifferent_access)

    entra_user.replicate_locally!
    existing_user.reload

    assert_equal "user@example.com", existing_user.login
    assert_equal "NewGivenName", existing_user.firstname
    assert_equal "NewSurname", existing_user.lastname
    assert_equal "user@example.com", existing_user.mail
    assert_equal "old-oid-12345", existing_user.oid
  end

  test "sets synced_at timestamp during replication" do
    freeze_time = Time.parse("2023-01-15 10:30:00 UTC")

    travel_to freeze_time do
      entra_user = EntraId::User.new({
        id: "12345678-1234-1234-1234-123456789012",
        userPrincipalName: "timestamp.test@example.com",
        mail: "timestamp.test@example.com",
        givenName: "Timestamp",
        surname: "Test"
      }.with_indifferent_access)

      entra_user.replicate_locally!

      user = User.find_by(login: "timestamp.test@example.com")
      assert_equal freeze_time, user.synced_at
    end
  end

  test "preserves existing Redmine-specific user data" do
    expected_created_on = 2.years.ago
    expected_last_login_on = 1.week.ago

    existing_user = User.create!(
      login: "preserve.test@example.com",
      firstname: "OldFirst",
      lastname: "OldLast",
      mail: "preserve.test@example.com",
      status: User::STATUS_LOCKED,
      admin: true,
      created_on: expected_created_on,
      last_login_on: expected_last_login_on
    )

    entra_user = EntraId::User.new({
      id: "12345678-1234-1234-1234-123456789012",
      userPrincipalName: "preserve.test@example.com",
      mail: "preserve.test@example.com",
      givenName: "NewFirst",
      surname: "NewLast"
    }.with_indifferent_access)

    entra_user.replicate_locally!
    existing_user.reload

    # EntraID attributes should be updated
    assert_equal "NewFirst", existing_user.firstname
    assert_equal "NewLast", existing_user.lastname
    assert_equal "12345678-1234-1234-1234-123456789012", existing_user.oid

    # Status should be set to active when syncing with EntraID
    assert_equal User::STATUS_ACTIVE, existing_user.status

    # Other Redmine-specific attributes should be preserved
    assert_equal true, existing_user.admin
    assert_in_delta expected_created_on, existing_user.created_on, 1.second
    assert_in_delta expected_last_login_on, existing_user.last_login_on, 1.second
  end

  test "falls back to displayName when givenName and surname are missing" do
    entra_user = EntraId::User.new({
      id: "12345678-1234-1234-1234-123456789012",
      userPrincipalName: "john.doe@example.com",
      mail: "john.doe@example.com",
      displayName: "John Doe"
    }.with_indifferent_access)

    assert_equal "John", entra_user.given_name
    assert_equal "Doe", entra_user.surname
  end

  test "falls back to displayName with single name" do
    entra_user = EntraId::User.new({
      id: "12345678-1234-1234-1234-123456789012",
      userPrincipalName: "john@example.com",
      mail: "john@example.com",
      displayName: "John"
    }.with_indifferent_access)

    assert_equal "John", entra_user.given_name
    assert_equal "User", entra_user.surname
  end

  test "falls back to Unknown User when no name information available" do
    entra_user = EntraId::User.new({
      id: "12345678-1234-1234-1234-123456789012",
      userPrincipalName: "unknown@example.com",
      mail: "unknown@example.com"
    }.with_indifferent_access)

    assert_equal "Unknown", entra_user.given_name
    assert_equal "User", entra_user.surname
  end
end
