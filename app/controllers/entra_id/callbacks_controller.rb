class EntraId::CallbacksController < AccountController
  rescue_from EntraId::NetworkError, with: :handle_network_error
  rescue_from JWT::VerificationError, with: :handle_jwt_error
  rescue_from OAuth2::Error, with: :handle_oauth_error

  before_action :ensure_entra_id_enabled, :handle_oauth_errors, :validate_oauth_state, :set_entra_id_identity
  after_action :cleanup_oauth_session

  def show
    user = User.find_by_identity(@identity)

    if user
      user.sync_with_identity(@identity)
      user.active? ? handle_active_user(user) : handle_inactive_user(user)
    else
      user = User.new @identity.to_user_params

      user.random_password
      user.register

      register_automatically user
    end
  end

  private

    def ensure_entra_id_enabled
      head :bad_request unless EntraId.enabled?
    end

    def handle_oauth_errors
      return unless params[:error]

      flash[:error] = params[:error_description]
      cleanup_oauth_session
      redirect_to signin_path
    end

    def validate_oauth_state
      received_state = params[:state]
      expected_state = session[:entra_id_state]

      if received_state.blank? || expected_state.blank?
        authentication_failed("Invalid OAuth credentials. Authentication failed")
      elsif !ActiveSupport::SecurityUtils.secure_compare(received_state, expected_state)
        authentication_failed("Invalid OAuth state. Authentication failed")
      end
    end

    def set_entra_id_identity
      authorization = EntraId::Authorization.new(
        redirect_uri: entra_id_callback_url,
        state: params[:state],
        nonce: session[:entra_id_nonce],
        code_verifier: session[:entra_id_pkce_verifier]
      )

      @identity = authorization.exchange_code_for_identity(code: params[:code])

      if @identity.blank?
        authentication_failed("Could not fetch identity from EntraID. Authentication failed.")
      end
    end

    def handle_network_error(exception)
      Rails.logger.error "EntraId network error: #{exception.message}"
      authentication_failed("Network error during authentication. Please try again.")
    end

    def handle_jwt_error(exception)
      Rails.logger.error "EntraId JWT verification error: #{exception.message}"
      authentication_failed("Invalid authentication token. Authentication failed.")
    end

    def handle_oauth_error(exception)
      Rails.logger.error "EntraId OAuth2 error: #{exception.message}"
      authentication_failed("Invalid OAuth token. Authentication failed.")
    end

    def authentication_failed(message)
      flash[:error] = message
      cleanup_oauth_session
      redirect_to signin_path
    end

    def cleanup_oauth_session
      session.delete(:entra_id_state)
      session.delete(:entra_id_nonce)
      session.delete(:entra_id_pkce_verifier)
    end
end
