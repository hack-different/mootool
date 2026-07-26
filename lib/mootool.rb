# typed: strict
# frozen_string_literal: true

require_relative 'moo_tool/version'

require 'macho'
require 'zip'
require 'uuidtools'
require 'json'

require_relative 'moo_tool/core_extensions'
require 'active_support/all'
require 'active_model'
require 'amazing_print'

ActiveSupport::Inflector.inflections do |inflect|
  inflect.acronym 'IMG4'
end

# MooTool
module MooTool
  class Error < StandardError; end

  extend ActiveSupport::Autoload

  autoload :Command, 'moo_tool/command'
  autoload :Decompressor, 'moo_tool/models/decompressor'

  module Commands
    autoload :IMG4, 'moo_tool/commands/img4'
  end

  module Helpers
    autoload :IMG4, 'moo_tool/helpers/img4'
  end

  autoload :Models
end

AmazingPrint.defaults = ({
  indent: 4, # Number of spaces for indenting.
  index: true, # Display array indices.
  html: false, # Use ANSI color codes rather than HTML.
  multiline: true, # Display in multiple lines.
  colors: :all, # Controls what should be colored. Can be one of :all, :values_only, or :none
  raw: false, # Do not recursively format instance variables.
  sort_keys: false,        # Do not sort hash keys.
  sort_vars: true,         # Sort instance variables.
  limit: false, # Limit arrays & hashes. Accepts bool or int.
  hash_format: :symbol, # The format for printing hashes. Can be one of :json, :rocket, or :symbol
  class_name: :class, # Method called to report the instance class name. (e.g. :to_s)
  object_id: true, # Show object id.
  color: {
    args: :whiteish,
    array: :white,
    bigdecimal: :blue,
    class: :yellow,
    date: :greenish,
    falseclass: :red,
    digest: :purple,
    uuid: :yellowish,
    integer: :blue,
    float: :blue,
    hash: :whiteish,
    keyword: :cyan,
    method: :purpleish,
    nilclass: :red,
    rational: :blue,
    string: :yellow,
    struct: :whiteish,
    symbol: :cyanish,
    time: :greenish,
    trueclass: :green,
    variable: :cyanish,
    path: :blue
  }
})

module AmazingPrint
  class Formatter
    include MooTool::Models::Digest::DigestFormatter
  end
end
