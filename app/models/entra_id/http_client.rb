# frozen_string_literal: true

class EntraId::HttpClient
  DEFAULT_READ_TIMEOUT = 10
  DEFAULT_OPEN_TIMEOUT = 5

  def initialize(base_uri, read_timeout: DEFAULT_READ_TIMEOUT, open_timeout: DEFAULT_OPEN_TIMEOUT)
    @base_uri = base_uri
    @http = Net::HTTP.new(@base_uri.host, @base_uri.port)
    @http.use_ssl = true if @base_uri.scheme == 'https'
    @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    @http.read_timeout = read_timeout
    @http.open_timeout = open_timeout
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

  def make_request(request, headers = {})
    headers.each { |key, value| request[key] = value }
    
    @http.request(request)
  rescue Net::ReadTimeout, Net::OpenTimeout, Timeout::Error => e
    raise EntraId::NetworkError, "Request timeout: #{e.message}"
  rescue OpenSSL::SSL::SSLError => e
    raise EntraId::NetworkError, "SSL verification failed: #{e.message}"
  rescue StandardError => e
    raise EntraId::NetworkError, "Network error: #{e.message}"
  end
end
