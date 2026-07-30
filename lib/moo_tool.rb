# typed: strict
# frozen_string_literal: true

require 'amazing_print'
require 'active_support/all'
require 'active_model'
require 'uuidtools'
require 'openssl'

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/mootool.rb")
loader.ignore("#{__dir__}/moo_tool/config/initializers")

loader.inflector.inflect(
  'img4' => 'IMG4',
  'ecc_public_key' => 'ECCPublicKey',
  'ecc_signature' => 'ECCSignature',
  'ecies_encryption' => 'ECIESEncryption',
  'io_reg' => 'IOReg',
  'ec_point_formatter' => 'ECPointFormatter',
  'ec_public_key' => 'ECPublicKey',
  'ecc_encryption_formatter' => 'ECCEncryptionFormatter',
)

loader.setup
loader.eager_load_dir("#{__dir__}/moo_tool/formatters")

Dir["#{__dir__}/moo_tool/config/initializers/*.rb"].each do |file|
  require_relative file
end

# MooTool
module MooTool
  class Error < StandardError; end
end

module AmazingPrint
  class Formatter
    include MooTool::Formatters
    MooTool::Formatters.constants.each do |constant|
      include MooTool::Formatters.const_get(constant)
    end
  end
end