class EntraId::AuthorizationsController < AccountController
  def new
    authorization = EntraId::Authorization.new redirect_uri: entra_id_callback_url

    session[:back_url] = params[:back_url]

    session[:entra_id_state] = authorization.state
    session[:entra_id_nonce] = authorization.nonce
    session[:entra_id_pkce_verifier] = authorization.code_verifier

    redirect_to authorization.url, allow_other_host: true
  end
end
