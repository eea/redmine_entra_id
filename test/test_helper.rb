# frozen_string_literal: true

# Load the Redmine helper
require_relative "../../../test/test_helper"

# WebMock setup for Minitest
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)
