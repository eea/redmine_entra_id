module EntraId
  # OAuth Configuration
  OAUTH_HOST = "login.microsoftonline.com"
  OAUTH_AUTHORIZE_PATH = "oauth2/v2.0/authorize"
  OAUTH_TOKEN_PATH = "oauth2/v2.0/token"
  OAUTH_JWKS_PATH = "discovery/v2.0/keys"
  OAUTH_SCOPE = "openid profile email"
  OAUTH_CHALLENGE_METHOD = "S256"

  # Graph API Configuration
  GRAPH_API_BASE = "https://graph.microsoft.com/v1.0"
  GRAPH_OAUTH_SCOPE = "https://graph.microsoft.com/.default"
  GRAPH_IDENTITY_URL = "#{GRAPH_API_BASE}/me"
  GRAPH_USERS_ENDPOINT = "#{GRAPH_API_BASE}/users"

  class << self
    def settings
      Setting.plugin_entra_id
    end

    def enabled?
      settings[:enabled]
    end

    def exclusive?
      settings[:exclusive]
    end

    def client_id
      settings[:client_id]
    end

    def client_secret
      raw_secret = settings[:client_secret]
      raw_secret.present? ? decrypt_client_secret(raw_secret) : ""
    end

    def masked_client_secret
      client_secret.blank? ? "" : "#{client_secret[0..2]}#{"*" * 18}"
    end

    def tenant_id
      settings[:tenant_id]
    end

    def valid?
      enabled? && client_id.present? && client_secret.present? && tenant_id.present?
    end

    def encrypt_client_secret(value)
      encryptor.encrypt_and_sign(value)
    end

    def raw_client_secret
      settings[:client_secret]
    end

    # URL Helpers
    def oauth_base_url
      "https://#{OAUTH_HOST}"
    end

    def tenant_oauth_base_url
      "#{oauth_base_url}/#{tenant_id}"
    end

    def authorize_path
      "#{tenant_id}/#{OAUTH_AUTHORIZE_PATH}"
    end

    def token_endpoint_path
      "#{tenant_id}/#{OAUTH_TOKEN_PATH}"
    end

    def token_endpoint_url
      "#{tenant_oauth_base_url}/#{OAUTH_TOKEN_PATH}"
    end

    def jwks_url
      "#{tenant_oauth_base_url}/#{OAUTH_JWKS_PATH}"
    end

    def authorize_url
      "#{tenant_oauth_base_url}/#{OAUTH_AUTHORIZE_PATH}"
    end

    def issuer_url
      "#{oauth_base_url}/#{tenant_id}/v2.0"
    end

    private

      def encryptor
        @encryptor ||= ActiveSupport::MessageEncryptor.new(
          Rails.application.key_generator.generate_key("entra_id_client_secret", 32)
        )
      end

      def decrypt_client_secret(payload)
        encryptor.decrypt_and_verify(payload)
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
        Rails.logger.error "Failed to decrypt EntraId client_secret - invalid encryption"
        ""
      end
  end
end
