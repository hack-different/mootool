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

require 'zeitwerk'

# MooTool
module MooTool
  class Error < StandardError; end
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

AmazingPrint::Formatter.class_eval do
  include MooTool::Formatters

  MooTool::Formatters.constants.each do |constant|
    include MooTool::Formatters.const_get(constant)
  end
end
