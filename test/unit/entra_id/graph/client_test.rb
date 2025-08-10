require_relative "../../../test_helper"

class EntraId::Graph::ClientTest < ActiveSupport::TestCase
  include GraphTestHelper

  test "builds the URI with no params" do
    assert_equal "https://graph.microsoft.com/v1.0/users",
      EntraId::Graph::Client.build_uri("/users").to_s
  end

  test "builds the URI with multiple selected fields" do
    assert_equal "https://graph.microsoft.com/v1.0/users?$select=id,givenName",
      EntraId::Graph::Client.build_uri("/users", select: [ "id", "givenName" ]).to_s
  end

  test "builds the URI with multiple selected fields and page size" do
    assert_equal "https://graph.microsoft.com/v1.0/users?$select=id,givenName&$top=999",
      EntraId::Graph::Client.build_uri("/users", select: [ "id", "givenName" ], top: 999).to_s
  end
  test "fetches a collection" do
    setup_graph_access_token

    anna = { id: "1", givenName: "Anna" }
    betty = { id: "2", givenName: "Betty" }

    stub_request(:get, "https://graph.microsoft.com/v1.0/users?$select=id,givenName&$top=10")
      .with(headers: { "Authorization" => "Bearer #{EntraId::Graph::AccessToken.instance.value}" })
      .to_return(
        status: 200,
        body: { value: [ anna, betty ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    client = EntraId::Graph::Client.new
    result = client.get "users", select: [ "id", "givenName" ], top: 10

    assert_equal "Anna", result.first["givenName"]
    assert_equal "Betty", result.second["givenName"]
  end

  test "fetches a paginated resource" do
    setup_graph_access_token
    token = EntraId::Graph::AccessToken.instance.value

    anna = { id: "1", givenName: "Anna" }
    betty = { id: "2", givenName: "Betty" }

    # First page with nextLink
    stub_request(:get, "https://graph.microsoft.com/v1.0/users?$select=id,givenName&$top=1")
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          value: [ anna ],
          "@odata.nextLink": "https://graph.microsoft.com/v1.0/users?$select=id,givenName&$top=1&$skiptoken=abc123"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Second page without nextLink (last page)
    stub_request(:get, "https://graph.microsoft.com/v1.0/users?$select=id,givenName&$top=1&$skiptoken=abc123")
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          value: [ betty ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    client = EntraId::Graph::Client.new
    result = client.get "users", select: [ "id", "givenName" ], top: 1

    assert_equal "Anna", result.first["givenName"]
    assert_equal "Betty", result.second["givenName"]
  end
end
