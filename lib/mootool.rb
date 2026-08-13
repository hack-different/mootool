# typed: strict
# frozen_string_literal: true

require 'amazing_print'
require 'active_support/all'
require 'active_model'
require 'uuidtools'
require 'openssl'
require 'digest'
require 'colorize'
require 'cfpropertylist'
require 'net/https'
require 'zip'
require 'plist'
require 'net/http'
require 'fileutils'
require 'apple_data'
require 'rasn2'
require 'gtk3'
require 'pathutil'

require 'zeitwerk'

# Main MooTool module providing utility functions and namespace for the project.
module MooTool
  # Generic error class for MooTool related exceptions.
  class Error < StandardError; end

  # The path to the Apple knowledge data.
  # @return [String]
  APPLE_DATA_PATH = ENV['APPLE_DATA'] || File.join(__dir__, '../data/apple-knowledge/_data')

  DATA_PATH = File.join(__dir__, '../data')
  UI_PATH = File.expand_path(File.join(__dir__, '../data/ui'))
  GRESOURCE_BIN = File.expand_path(File.join(__dir__, '../data/ui/resources.bin'))

  # The base path for temporary files.
  # @return [String]
  TEMP_PATH = File.join(__dir__, '../tmp')

  # Ensures a temporary directory exists for the given namespace and returns its absolute path.
  #
  # @param namespace [String, nil] optional subdirectory name within the temporary path.
  # @return [String] the absolute real path to the temporary directory.
  # @example Create a namespaced temporary directory
  #   MooTool.temp_directory('extraction') # => "/absolute/path/to/mootool/tmp/extraction"
  def self.temp_directory(namespace = nil)
    full_path = File.join(TEMP_PATH, namespace)
    FileUtils.mkdir_p(full_path)
    File.realpath full_path
  end
end

Dir["#{__dir__}/mootool/config/initializers/*.rb"].each do |file|
  require_relative file
end

loader = Zeitwerk::Loader.new
loader.tag = File.basename(__FILE__, '.rb')
loader.push_dir("#{__dir__}/mootool", namespace: MooTool)
loader.ignore("#{__dir__}/mootool/config/initializers")
loader.inflector = ActiveSupport::Inflector
loader.setup
loader.eager_load_dir("#{__dir__}/mootool/formatters")

AppleData.data_location = ENV['APPLE_DATA'] if ENV['APPLE_DATA']

AmazingPrint::Formatter.class_eval do
  include MooTool::Formatters

  MooTool::Formatters.constants.each do |constant|
    include MooTool::Formatters.const_get(constant)
  end
end
