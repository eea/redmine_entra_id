# frozen_string_literal: true

# Load the Redmine helper
require_relative "../../../test/test_helper"
require "webmock/minitest"

require_relative "support/oauth_test_helper"
require_relative "support/graph_test_helper"
require_relative "support/entra_id_env_helper"

WebMock.disable_net_connect!(allow_localhost: true)

# Include the environment helper in all tests
ActiveSupport::TestCase.include(EntraIdEnvHelper)

# Configure fixture path for plugin tests
ActiveSupport::TestCase.file_fixture_path = Rails.root.join("plugins/entra_id/test/fixtures")
