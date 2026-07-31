# typed: strict
# frozen_string_literal: true

require 'zeitwerk'
require_relative '../lib/mootool'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expose_dsl_globally = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

FIXTURE_PATH = File.realpath(File.join(File.dirname(__FILE__), 'fixtures'))

def fixture_file(file)
  File.join(FIXTURE_PATH, file)
end
