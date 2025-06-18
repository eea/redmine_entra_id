# frozen_string_literal: true

require_relative "../../test_helper"

class EntraId::SecureHttpClientTest < ActiveSupport::TestCase
  test "creates HTTP client with secure SSL configuration" do
    uri = URI("https://example.com/api")
    
    client = EntraId::SecureHttpClient.new(uri)
    
    assert client.use_ssl?
    assert_equal OpenSSL::SSL::VERIFY_PEER, client.verify_mode
    assert_equal 10, client.read_timeout
    assert_equal 5, client.open_timeout
  end

  test "makes GET request with timeout protection" do
    uri = URI("https://example.com/api")
    
    stub_request(:get, "https://example.com/api")
      .to_return(status: 200, body: '{"success": true}')
    
    client = EntraId::SecureHttpClient.new(uri)
    response = client.get("/api")
    
    assert response.is_a?(Net::HTTPSuccess)
    assert_equal '{"success": true}', response.body
  end

  test "makes POST request with secure configuration" do
    uri = URI("https://example.com/token")
    
    stub_request(:post, "https://example.com/token")
      .with(body: "grant_type=client_credentials")
      .to_return(status: 200, body: '{"access_token": "test-token"}')
    
    client = EntraId::SecureHttpClient.new(uri)
    response = client.post("/token", "grant_type=client_credentials", {
      "Content-Type" => "application/x-www-form-urlencoded"
    })
    
    assert response.is_a?(Net::HTTPSuccess)
    assert_equal '{"access_token": "test-token"}', response.body
  end

  test "handles timeout errors gracefully" do
    uri = URI("https://example.com/slow")
    
    stub_request(:get, "https://example.com/slow")
      .to_timeout
    
    client = EntraId::SecureHttpClient.new(uri)
    
    assert_raises(EntraId::NetworkError) do
      client.get("/slow")
    end
  end

  test "handles SSL verification errors" do
    uri = URI("https://invalid-ssl.example.com/api")
    
    stub_request(:get, "https://invalid-ssl.example.com/api")
      .to_raise(OpenSSL::SSL::SSLError.new("SSL verification failed"))
    
    client = EntraId::SecureHttpClient.new(uri)
    
    assert_raises(EntraId::NetworkError) do
      client.get("/api")
    end
  end
end
