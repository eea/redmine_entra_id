module EntraId::MaskableSettings
  extend ActiveSupport::Concern

  included do
    before_action :prepare_entra_id_settings, only: [ :plugin ]
  end

  private

    def prepare_entra_id_settings
      return unless params[:id] == "entra_id"
      return unless request.post?

      received_client_secret = params.dig(:settings, :client_secret)

      if received_client_secret == EntraId.masked_client_secret
        # User didn't change the secret, keep the encrypted value
        params[:settings][:client_secret] = EntraId.raw_client_secret
      elsif received_client_secret.present?
        # User provided a new secret, encrypt it
        params[:settings][:client_secret] = EntraId.encrypt_client_secret(received_client_secret)
      end
    end
end
