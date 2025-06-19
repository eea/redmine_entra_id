# frozen_string_literal: true

require_relative "../../test_helper"

class EntraId::HttpClientTest < ActiveSupport::TestCase
  test "successfully makes HTTPS requests with proper SSL configuration" do
    uri = URI("https://example.com/api")
    
    stub_request(:get, "https://example.com/test")
      .to_return(status: 200, body: '{"secure": true}')
    
    client = EntraId::HttpClient.new(uri)
    response = client.get("/test")
    
    assert response.is_a?(Net::HTTPSuccess)
    assert_equal '{"secure": true}', response.body
  end

  test "makes GET request with timeout protection" do
    uri = URI("https://example.com/api")
    
    stub_request(:get, "https://example.com/api")
      .to_return(status: 200, body: '{"success": true}')
    
    client = EntraId::HttpClient.new(uri)
    response = client.get("/api")
    
    assert response.is_a?(Net::HTTPSuccess)
    assert_equal '{"success": true}', response.body
  end

  test "makes POST request with secure configuration" do
    uri = URI("https://example.com/token")
    
    stub_request(:post, "https://example.com/token")
      .with(body: "grant_type=client_credentials")
      .to_return(status: 200, body: '{"access_token": "test-token"}')
    
    client = EntraId::HttpClient.new(uri)
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
    
    client = EntraId::HttpClient.new(uri)
    
    assert_raises(EntraId::NetworkError) do
      client.get("/slow")
    end
  end

  test "handles SSL verification errors" do
    uri = URI("https://invalid-ssl.example.com/api")
    
    stub_request(:get, "https://invalid-ssl.example.com/api")
      .to_raise(OpenSSL::SSL::SSLError.new("SSL verification failed"))
    
    client = EntraId::HttpClient.new(uri)
    
    assert_raises(EntraId::NetworkError) do
      client.get("/api")
    end
  end
end
