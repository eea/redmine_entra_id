require_relative "../../test_helper"

class EntraId::NametagTest < ActiveSupport::TestCase
  test "uses given_name and surname when available" do
    nametag = EntraId::Nametag.new(
      given_name: "John",
      surname: "Doe",
      display_name: "John A. Doe"
    )

    assert_equal "John", nametag.first_name
    assert_equal "Doe", nametag.last_name
  end

  test "falls back to display_name when given_name is missing" do
    nametag = EntraId::Nametag.new(
      given_name: nil,
      surname: "Doe",
      display_name: "Johnny A. Doe"
    )

    assert_equal "Johnny", nametag.first_name
    assert_equal "Doe", nametag.last_name
  end

  test "falls back to display_name when surname is missing" do
    nametag = EntraId::Nametag.new(
      given_name: "John",
      surname: nil,
      display_name: "John A. Smith"
    )

    assert_equal "John", nametag.first_name
    assert_equal "A. Smith", nametag.last_name
  end

  test "parses multiple names from display_name" do
    nametag = EntraId::Nametag.new(
      given_name: nil,
      surname: nil,
      display_name: "John A. Doe"
    )

    assert_equal "John", nametag.first_name
    assert_equal "A. Doe", nametag.last_name
  end

  test "handles single name from display_name" do
    nametag = EntraId::Nametag.new(
      given_name: nil,
      surname: nil,
      display_name: "John"
    )

    assert_equal "John", nametag.first_name
    assert_equal "User", nametag.last_name
  end

  test "handles missing name information" do
    nametag = EntraId::Nametag.new(
      given_name: nil,
      surname: nil,
      display_name: nil
    )

    assert_equal "Unknown", nametag.first_name
    assert_equal "User", nametag.last_name
  end

  test "handles empty display_name" do
    nametag = EntraId::Nametag.new(
      given_name: "",
      surname: "",
      display_name: ""
    )

    assert_equal "Unknown", nametag.first_name
    assert_equal "User", nametag.last_name
  end
end