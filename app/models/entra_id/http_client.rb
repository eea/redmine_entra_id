# frozen_string_literal: true

class EntraId::HttpClient
  include ActiveSupport::Configurable

  config_accessor :read_timeout
  config_accessor :open_timeout

  self.read_timeout = 10
  self.open_timeout = 5

  attr_reader :base_uri, :http

  def initialize(base_uri, read_timeout: self.class.read_timeout, open_timeout: self.class.open_timeout)
    @base_uri = base_uri
    @http = configure_http_client(read_timeout, open_timeout)
  end

  def get(path, headers = {})
    make_request(Net::HTTP::Get.new(path), headers)
  end

  def post(path, body = nil, headers = {})
    request = Net::HTTP::Post.new(path)
    request.body = body if body
    make_request(request, headers)
  end

  private

  def configure_http_client(read_timeout, open_timeout)
    http = Net::HTTP.new(base_uri.host, base_uri.port)

    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.read_timeout = read_timeout
    http.open_timeout = open_timeout

    http
  end

  def make_request(request, headers = {})
    headers.each { |key, value| request[key] = value }
    
    Rails.logger.debug "EntraId HTTP #{request.method} #{base_uri}#{request.path}"
    
    response = http.request(request)
    
    Rails.logger.debug "EntraId HTTP Response: #{response.code} #{response.message}"
    response
  rescue Net::ReadTimeout, Net::OpenTimeout, Timeout::Error => e
    Rails.logger.error "EntraId HTTP timeout: #{e.message}"
    raise EntraId::NetworkError, "Request timeout: #{e.message}"
  rescue OpenSSL::SSL::SSLError => e
    Rails.logger.error "EntraId SSL error: #{e.message}"
    raise EntraId::NetworkError, "SSL verification failed: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "EntraId network error: #{e.message}"
    raise EntraId::NetworkError, "Network error: #{e.message}"
  end
end
