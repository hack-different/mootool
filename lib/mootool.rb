# typed: strict
# frozen_string_literal: true

require_relative 'moo_tool/version'

require 'macho'
require 'zip'
require 'pathname'

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

  module Commands
    autoload :IMG4, 'moo_tool/commands/img4'
  end

  autoload :Models

  class Digest
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def to_s
      if value.respond_to?(:unpack1)
                value.unpack1('H*')
      else
        value.to_s
        end

    end

    def shasum
      to_s.upcase
    end

    def file_names(sums)
      if sums.index.has_key? self.shasum
        { hash: self,
          files:
        sums.index[self.shasum] }
      else
        self
      end
    end

    def inspect
      to_s.upcase
    end
  end

  module Formatters
    module DigestFormatter
      def self.included(base)
        base.send :alias_method, :cast_without_digest, :cast
        base.send :alias_method, :cast, :cast_with_digest
      end

      def cast_with_digest(object, type)
        cast = cast_without_digest(object, type)

        case object
        when Digest
          cast = :digest
        when Pathname
          cast = :path
        end
        cast
      end

      def awesome_digest(object)
        colorize(object.inspect, :digest)
      end

      def awesome_path(object)
        colorize(object.to_s, :path)
      end
    end
  end
end


AmazingPrint.defaults =({
  indent: 4,            # Number of spaces for indenting.
  index: true,         # Display array indices.
  html: false,        # Use ANSI color codes rather than HTML.
  multiline: true,         # Display in multiple lines.
  colors: :all, # Controls what should be colored. Can be one of :all, :values_only, or :none
  raw: false,        # Do not recursively format instance variables.
  sort_keys: false,        # Do not sort hash keys.
  sort_vars: true,         # Sort instance variables.
  limit: false,        # Limit arrays & hashes. Accepts bool or int.
  hash_format: :symbol,      # The format for printing hashes. Can be one of :json, :rocket, or :symbol
  class_name: :class,       # Method called to report the instance class name. (e.g. :to_s)
  object_id: true,         # Show object id.
  color: {
    args: :whiteish,
    array: :white,
    bigdecimal: :blue,
    class: :yellow,
    date: :greenish,
    falseclass: :red,
    digest: :purple,
    integer: :blue,
    float: :blue,
    hash: :whiteish,
    keyword: :cyan,
    method: :purpleish,
    nilclass: :red,
    rational: :blue,
    string: :yellowish,
    struct: :whiteish,
    symbol: :cyanish,
    time: :greenish,
    trueclass: :green,
    variable: :cyanish,
    path: :blue
  }
})

class AmazingPrint::Formatter
  include MooTool::Formatters::DigestFormatter
end