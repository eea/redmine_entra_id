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

    def application_id
      settings[:application_id]
    end

    def client_secret
      secret = settings[:client_secret]
      secret.present? ? "#{secret[0..2]}#{"*" * 18}" : ""
    end

    def directory_id
      settings[:directory_id]
    end
  end
end

require_relative "entra_id/hooks/views/login_view_hooks"
