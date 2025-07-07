# frozen_string_literal: true

module EntraIdEnvHelper
  extend ActiveSupport::Concern
  
  included do
    setup :setup_entra_id_env
    teardown :teardown_entra_id_env
  end
  
  def setup_entra_id_env
    ENV["ENTRA_ID_CLIENT_ID"] = "test-client-id"
    ENV["ENTRA_ID_CLIENT_SECRET"] = "test-secret-123"
    ENV["ENTRA_ID_TENANT_ID"] = "test-tenant-id"
  end
  
  def teardown_entra_id_env
    ENV.delete("ENTRA_ID_CLIENT_ID")
    ENV.delete("ENTRA_ID_CLIENT_SECRET")
    ENV.delete("ENTRA_ID_TENANT_ID")
  end
end