require_relative "../../../test_helper"

class EntraId::Graph::AccessTokenTest < ActiveSupport::TestCase
  setup do
    # Force token to expire immediately, ensuring clean state for each test
    stub_request(:post, EntraId::Graph::AccessToken.uri)
      .to_return(
        status: 200,
        body: {
          "access_token" => "setup_token",
          "token_type" => "Bearer",
          "expires_in" => 0  # Expires immediately
        }.to_json
      )

    EntraId::Graph::AccessToken.instance.value(force_refresh: true)

    # Clear WebMock history so setup requests don't affect test assertions
    WebMock.reset_executed_requests!
  end
  
  test "fetches access token on first request" do
    token = "fresh_token_abc123"

    stub_request(:post, EntraId::Graph::AccessToken.uri)
      .with(
        body: EntraId::Graph::AccessToken.token_params,
        headers: { "Content-Type" => "application/x-www-form-urlencoded" }
      )
      .to_return(
        status: 200,
        body: {
          "access_token" => token,
          "token_type" => "Bearer",
          "expires_in" => 3600
        }.to_json
      )

    assert_equal token, EntraId::Graph::AccessToken.instance.value
    assert_requested :post, EntraId::Graph::AccessToken.uri, times: 1
  end

  test "reuses access token on subsequent requests" do
    token = "cached_token_xyz789"

    stub_request(:post, EntraId::Graph::AccessToken.uri)
      .to_return(
        status: 200,
        body: {
          "access_token" => token,
          "token_type" => "Bearer",
          "expires_in" => 3600
        }.to_json
      )

    # First request fetches the token
    assert_equal token, EntraId::Graph::AccessToken.instance.value
    # Second request should reuse the cached token
    assert_equal token, EntraId::Graph::AccessToken.instance.value
    assert_requested :post, EntraId::Graph::AccessToken.uri, times: 1
  end

  test "fetches fresh access token after expiration" do
    initial_token = "initial_token_123"
    refreshed_token = "refreshed_token_456"

    stub_request(:post, EntraId::Graph::AccessToken.uri)
      .to_return(
        status: 200,
        body: {
          "access_token" => initial_token,
          "token_type" => "Bearer",
          "expires_in" => 1.hour
        }.to_json
      ).then.to_return(
        status: 200,
        body: {
          "access_token" => refreshed_token,
          "token_type" => "Bearer",
          "expires_in" => 1.hour
        }.to_json
      )

    # First request gets initial token
    assert_equal initial_token, EntraId::Graph::AccessToken.instance.value

    # Wait for token to expire
    travel_to 70.minutes.from_now do
      assert_equal refreshed_token, EntraId::Graph::AccessToken.instance.value
    end
  end

  test "refreshes the token on demand" do
    valid_token = "still_valid_token"
    new_token = "manually_refreshed_token"

    stub_request(:post, EntraId::Graph::AccessToken.uri)
      .to_return(
        status: 200,
        body: {
          "access_token" => valid_token,
          "token_type" => "Bearer",
          "expires_in" => 1.hour  # Token is still valid for an hour
        }.to_json
      ).then.to_return(
        status: 200,
        body: {
          "access_token" => new_token,
          "token_type" => "Bearer",
          "expires_in" => 1.hour
        }.to_json
      )

    # Get initial token
    assert_equal valid_token, EntraId::Graph::AccessToken.instance.value

    # Force refresh even though token is still valid
    refreshed = EntraId::Graph::AccessToken.instance.value(force_refresh: true)

    assert_equal new_token, refreshed
    assert_equal new_token, EntraId::Graph::AccessToken.instance.value
    assert_requested :post, EntraId::Graph::AccessToken.uri, times: 2
  end

  test "automatically refreshes the token before it expires" do
    initial_token = "about_to_expire_token"
    refreshed_token = "fresh_token_with_buffer"

    stub_request(:post, EntraId::Graph::AccessToken.uri)
      .to_return(
        status: 200,
        body: {
          "access_token" => initial_token,
          "token_type" => "Bearer",
          "expires_in" => 60  # Expires in 60 seconds
        }.to_json
      ).then.to_return(
        status: 200,
        body: {
          "access_token" => refreshed_token,
          "token_type" => "Bearer",
          "expires_in" => 3600
        }.to_json
      )

    # Get initial token
    assert_equal initial_token, EntraId::Graph::AccessToken.instance.value

    # Move forward to 31 seconds from now (within the 30-second buffer)
    # Token expires at 60 seconds, buffer is 30 seconds, so refresh should happen at 30 seconds
    travel_to 31.seconds.from_now do
      assert_equal refreshed_token, EntraId::Graph::AccessToken.instance.value
    end

    assert_requested :post, EntraId::Graph::AccessToken.uri, times: 2
  end
end
