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

require 'zeitwerk'

# MooTool
module MooTool
  class Error < StandardError; end
  DATA_PATH = File.join(__dir__, '../data/apple-knowledge/_data')
  TEMP_PATH = File.join(__dir__, '../tmp')

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
