module MaskableEntraIdSettings
  extend ActiveSupport::Concern

  included do
    before_action :prepare_entra_id_settings, only: [ :plugin ]
  end

  private

    def prepare_entra_id_settings
      return unless params[:id] == "entra_id"
      return unless request.post?

      received_client_secret = params.dig(:settings, :client_secret)
      masked_client_secret = EntraId.masked_client_secret

      if received_client_secret == masked_client_secret
        params[:settings][:client_secret] = EntraId.client_secret
      end
    end
end
