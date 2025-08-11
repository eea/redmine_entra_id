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

  def initialize
    @http = nil
  end

  # Block-based API for connection reuse
  def perform(&block)
    @http = Net::HTTP.start(GRAPH_HOST, URI::HTTPS.default_port, use_ssl: true)
    @http.read_timeout = 120  # Increase for long-running operations
    @http.keep_alive_timeout = 30

    yield self
  ensure
    @http.finish if @http && @http.started?
    @http = nil
  end

  def get(path, params = {})
    with_http do |http|
      uri = self.class.build_uri("/#{path}", params)
      request = build_request_for(uri)

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

    def with_http(&block)
      if @http && @http.started?
        # Use existing connection from perform block
        yield @http
      else
        # Create temporary connection for standalone requests
        Net::HTTP.start(GRAPH_HOST, URI::HTTPS.default_port, use_ssl: true) do |http|
          yield http
        end
      end
    end

    def build_request_for(uri)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{EntraId::Graph::AccessToken.instance.value}"
      request
    end
end
