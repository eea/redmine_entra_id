module EntraId
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

    def encrypt_client_secret(value)
      encryptor.encrypt_and_sign(value)
    end

    def raw_client_secret
      settings[:client_secret]
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
