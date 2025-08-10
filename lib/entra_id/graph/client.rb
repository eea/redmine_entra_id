class EntraId::Graph::Client
  GRAPH_HOST = "graph.microsoft.com"
  GRAPH_VERSION = "v1.0"

  MAX_PAGE_SIZE = 999

  class << self
    def build_uri(path, params = {})
      URI::HTTPS.build(
        host: GRAPH_HOST,
        path: "/#{GRAPH_VERSION}#{path}",
        query: query_params(params)
      )
    end

    private

      def query_params(params = {})
        params.map { |k, v| "$#{k}=#{Array.wrap(v).join(",")}" }.join("&").presence
      end
  end

  def get(path, params = {})
    Net::HTTP.start(GRAPH_HOST, URI::HTTPS.default_port, use_ssl: true) do |http|
      request = build_request_for(EntraId::Graph::Client.build_uri("/#{path}", params))

      data = JSON.parse(http.request(request).body)
      collection = data["value"]

      # Fetch additional pages if paginated
      while data["@odata.nextLink"]
        request = build_request_for(URI(data["@odata.nextLink"]))
        data = JSON.parse(http.request(request).body)

        collection.concat(data["value"])
      end

      collection
    end
  end

  private

    def build_request_for(uri)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{EntraId::Graph::AccessToken.instance.value}"
      request
    end
end
