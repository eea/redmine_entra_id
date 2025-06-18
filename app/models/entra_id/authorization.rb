class EntraId::Authorization
  HOST = "login.microsoftonline.com"

  AUTHORIZE_PATH = "oauth2/v2.0/authorize"
  TOKEN_PATH = "oauth2/v2.0/token"
  JWKS_PATH = "discovery/v2.0/keys"

  SCOPE = "openid profile email"
  CHALLENGE_METHOD = "S256"

  attr_reader :code_verifier, :state, :nonce, :redirect_uri

  def initialize(redirect_uri:, code_verifier: nil, state: nil, nonce: nil)
    @redirect_uri = redirect_uri

    @code_verifier = code_verifier || SecureRandom.urlsafe_base64(64)
    @state = state || SecureRandom.hex(16)
    @nonce = nonce || SecureRandom.hex(16)
  end

  def code_challenge
    Base64.urlsafe_encode64 Digest::SHA256.digest(code_verifier), padding: false
  end

  def url
    client.auth_code.authorize_url(
      redirect_uri: redirect_uri,
      scope: SCOPE,
      response_mode: "query",
      state: state,
      nonce: nonce,
      code_challenge: code_challenge,
      code_challenge_method: CHALLENGE_METHOD,
      prompt: "select_account"
    )
  end

  def exchange_code_for_identity(code:)
    access_token = exchange_code_for_access_token(code)
    claims = decode_id_token(access_token.params["id_token"])

    if ActiveSupport::SecurityUtils.secure_compare(claims["nonce"], nonce)
      EntraId::Identity.new claims: claims, access_token: access_token.token
    else
      Rails.logger.error "Invalid nonce detected"

      nil
    end
  rescue JWT::VerificationError => e
    Rails.logger.error "EntraId token validation error (#{e.message})"

    nil
  end

  private

    def client
      @client ||= OAuth2::Client.new(
        EntraId.client_id,
        EntraId.client_secret,
        site: "https://#{HOST}",
        authorize_url: "#{EntraId.tenant_id}/#{AUTHORIZE_PATH}",
        token_url: "#{EntraId.tenant_id}/#{TOKEN_PATH}",
        auth_scheme: :request_body
      )
    end

    def exchange_code_for_access_token(code)
      client.auth_code.get_token(
        code,
        { redirect_uri: redirect_uri, code_verifier: code_verifier }
      )
    end

    def decode_id_token(id_token)
      data, _header = JWT.decode(
        id_token, nil, true,
        {
          algorithms: [ "RS256" ],
          jwks: jwks,
          verify_aud: true,
          aud: EntraId.client_id,
          verify_iss: true,
          iss: "https://#{HOST}/#{EntraId.tenant_id}/v2.0",
          verify_iat: true
        }
      )

      data
    end

    def jwks
      uri = URI("https://#{HOST}/#{EntraId.tenant_id}/#{JWKS_PATH}")

      client = EntraId::SecureHttpClient.new(uri)
      response = client.get(uri.request_uri)

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        nil
      end
    rescue JSON::ParserError
      Rails.logger.error "Failed to parse #{response.body}"

      nil
    end
end
