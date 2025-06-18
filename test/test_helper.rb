# frozen_string_literal: true

# Load the Redmine helper
require_relative "../../../test/test_helper"
require "webmock/minitest"

require_relative "support/oauth_test_helper"
require_relative "support/entra_id_directory_helper"

WebMock.disable_net_connect!(allow_localhost: true)
