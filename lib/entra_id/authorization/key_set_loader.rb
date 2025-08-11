class EntraId::Authorization::KeySetLoader
  JWKS_PATH = "discovery/v2.0/keys"
  CACHE_KEY = "entra_id_jwks_with_ttl"

  def call(options)
    raise "EntraId not properly configured" unless EntraId.valid?

    cached_data = Rails.cache.read(CACHE_KEY)

    if options[:kid_not_found] || cached_data.nil? || Time.current > cached_data[:expires_at]
      fetch_jwks_from_microsoft
    else
      cached_data[:keys]
    end
  end

  private

  def fetch_jwks_from_microsoft
    uri = jwks_url
    client = EntraId::HttpClient.new(uri)
    response = client.get(uri.request_uri)

    if response.is_a?(Net::HTTPSuccess)
      keys = JSON.parse(response.body)

      # Parse Cache-Control header for max-age
      cache_control = response["Cache-Control"]
      max_age = if cache_control && cache_control =~ /max-age=(\d+)/
        $1.to_i
      else
        3600 # Default to 1 hour
      end

      expires_at = Time.current + max_age.seconds

      # Store both keys and expiration time
      cache_data = { keys: keys, expires_at: expires_at }
      Rails.cache.write(CACHE_KEY, cache_data)

      keys
    else
      Rails.logger.error "Failed to fetch JWKS: #{response.code} #{response.body}"
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse JWKS response: #{e.message}"
    nil
  end

  def jwks_url
    URI::HTTPS.build(
      host: EntraId::OAUTH_HOST,
      path: "/#{EntraId.tenant_id}/#{JWKS_PATH}"
    )
  end
end
