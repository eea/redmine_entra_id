class EntraId::CallbacksController < AccountController
  before_action :handle_oauth_errors, :validate_oauth_state, :verify_pkce,
    :set_entra_id_identity

  def show
    user = User.by_email_or_login(@identity.preferred_username).first

    if user
      user.active? ? handle_active_user(user) : handle_inactive_user(user)
    elsif Setting.self_registration?
      user = User.new @identity.to_user_params

      user.random_password
      user.register

      register_automatically user
    else
      flash[:error] = "Account does not exist and self-registration is disabled"
      redirect_to signin_path
    end
  end

  private

    def handle_oauth_errors
      return unless params[:error]

      flash[:error] = params[:error_description]
      redirect_to signin_path
    end

    def validate_oauth_state
      received_state = params[:state]
      expected_state = session[:entra_id_state]

      if received_state.blank? || expected_state.blank?
        flash[:error] = "Invalid OAuth credentials. Authentication failed"
      elsif !ActiveSupport::SecurityUtils.secure_compare(received_state, expected_state)
        flash[:error] = "Invalid OAuth state. Authentication failed"
        redirect_to signing_path
      end
    end

    def verify_pkce
      return if session[:entra_id_pkce_verifier]

      flash[:error] = "PKCE verifier is missing. Authentication failed."
      redirect_to signin_path
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
        flash[:error] = "Could not fetch identity from EntraID. Authentication failed."
        redirect_to signin_path
      end
    rescue OAuth2::Error => e
      Rails.logger.error "OAuth2 errors: #{e.message}"

      flash[:error] = "Invalid OAuth token. Authentication failed."
      redirect_to signin_path
    end
end
