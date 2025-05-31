# frozen_string_literal: true

require "test_helper"

class EntraIdTest < ActiveSupport::TestCase
  def setup
    @original_settings = Setting.plugin_entra_id.dup
    # Set up a test secret (encrypted)
    encrypted_secret = EntraId.encrypt_client_secret("test-secret-123")
    Setting.plugin_entra_id = {
      enabled: true,
      exclusive: false,
      client_id: "test-client-id",
      client_secret: encrypted_secret,
      tenant_id: "test-tenant-id"
    }
  end

  def teardown
    Setting.plugin_entra_id = @original_settings
  end

  test "client_secret returns decrypted value for encrypted secrets" do
    encrypted_secret = EntraId.encrypt_client_secret("my-secret-key")
    Setting.plugin_entra_id = Setting.plugin_entra_id.merge(client_secret: encrypted_secret)

    assert_equal "my-secret-key", EntraId.client_secret
  end

  test "client_secret returns empty string for blank values" do
    Setting.plugin_entra_id = Setting.plugin_entra_id.merge(client_secret: "")

    assert_equal "", EntraId.client_secret
  end

  test "client_secret returns empty string for nil values" do
    Setting.plugin_entra_id = Setting.plugin_entra_id.merge(client_secret: nil)

    assert_equal "", EntraId.client_secret
  end

  test "encrypt_client_secret returns encrypted value" do
    encrypted = EntraId.encrypt_client_secret("test-secret")

    assert_not_equal "test-secret", encrypted
    assert encrypted.present?
  end

  test "encrypt_client_secret and decrypt round trip works" do
    original_secret = "my-super-secret-key"
    encrypted = EntraId.encrypt_client_secret(original_secret)

    # Set the encrypted value and verify it decrypts correctly
    Setting.plugin_entra_id = Setting.plugin_entra_id.merge(client_secret: encrypted)

    assert_equal original_secret, EntraId.client_secret
  end

  test "raw_client_secret returns stored value without decryption" do
    encrypted_secret = EntraId.encrypt_client_secret("my-secret")
    Setting.plugin_entra_id = Setting.plugin_entra_id.merge(client_secret: encrypted_secret)

    assert_equal encrypted_secret, EntraId.raw_client_secret
    assert_not_equal "my-secret", EntraId.raw_client_secret
  end

  test "masked_client_secret shows first 3 characters with asterisks" do
    encrypted_secret = EntraId.encrypt_client_secret("secret123456789")
    Setting.plugin_entra_id = Setting.plugin_entra_id.merge(client_secret: encrypted_secret)

    assert_equal "sec******************", EntraId.masked_client_secret
  end

  test "masked_client_secret works with encrypted secrets" do
    encrypted_secret = EntraId.encrypt_client_secret("secret123456789")
    Setting.plugin_entra_id = Setting.plugin_entra_id.merge(client_secret: encrypted_secret)

    assert_equal "sec******************", EntraId.masked_client_secret
  end

  test "masked_client_secret returns empty string for blank secrets" do
    Setting.plugin_entra_id = Setting.plugin_entra_id.merge(client_secret: "")

    assert_equal "", EntraId.masked_client_secret
  end

  test "all settings accessors work correctly" do
    assert_equal true, EntraId.enabled?
    assert_equal false, EntraId.exclusive?
    assert_equal "test-client-id", EntraId.client_id
    assert_equal "test-secret-123", EntraId.client_secret
    assert_equal "test-tenant-id", EntraId.tenant_id
  end
end
