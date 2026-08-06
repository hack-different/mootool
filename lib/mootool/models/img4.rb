# typed: false
# frozen_string_literal: true

require 'openssl'
require 'amazing_print'
require_relative 'decompressor'
require 'cfpropertylist'

module MooTool
  module Models
    # Module for Apple's IMG4 encryption and signing format
    module IMG4
      def self.parse_4cc(input)
        input.map do |value|
          value.b.unpack1('N')
        end
      end

      HASH_FILENAME = /(?<hash>\h{96})/

      def self.mappings
        @mappings ||= AppleData::Schemas::IMG4.new.all
        @mappings
      end

      def self.friendly=(friendly)
        @friendly = friendly
      end

      def self.friendly
        @friendly ||= false
      end

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
