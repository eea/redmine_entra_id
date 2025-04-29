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
      settings[:client_secret]
    end

    def masked_client_secret
      if client_secret.blank?
        ""
      else
        "#{client_secret[0..2]}#{"*" * 18}"
      end
    end

    def tenant_id
      settings[:tenant_id]
    end
  end
end
