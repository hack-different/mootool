# typed: false
# frozen_string_literal: true

require 'openssl'
require 'amazing_print'
require_relative 'decompressor'
require 'cfpropertylist'

module MooTool
  module Models
    # Module for Apple's IMG4 encryption and signing format.
    # Contains utility methods for parsing 4CC codes and handling IMG4 key mappings.
    module IMG4
      # Parses a list of strings as 4-character codes (4CC) into integers.
      #
      # @param input [Array<String>] A list of 4-character strings.
      # @return [Array<Integer>] A list of big-endian 32-bit integers.
      def self.parse_4cc(input)
        input.map do |value|
          value.b.unpack1('N')
        end
      end

      # Regular expression to extract a 96-character hex hash from a filename.
      HASH_FILENAME = /(?<hash>\h{96})/

      # Returns the IMG4 key mappings from the AppleData schema.
      #
      # @return [Hash] The mappings of IMG4 tags to descriptive names.
      def self.mappings
        @mappings ||= AppleData::Schemas::IMG4.new.all
        @mappings
      end

      # Sets whether to use friendly names for IMG4 keys.
      #
      # @param friendly [Boolean] True to use friendly names, false otherwise.
      def self.friendly=(friendly)
        @friendly = friendly
      end

      # Returns whether friendly names are currently enabled.
      #
      # @return [Boolean] True if friendly names are enabled.
      def self.friendly
        @friendly ||= false
      end

      # Returns a descriptive name for an IMG4 key tag if friendly names are enabled.
      #
      # @param key [String, Symbol] The IMG4 tag (e.g., 'IM4M').
      # @return [Models::DescriptorResult, Symbol] The descriptive result or the original key.
      def self.key_name(key)
        key = key.to_sym unless key.is_a?(Symbol)

        if friendly
          string_result = mappings[key].to_s
          return Models::DescriptorResult.new key, string_result if string_result
        end

        key
      end
    end
  end
end
