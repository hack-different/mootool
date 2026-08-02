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
        file_path = ::File.join(ENV['APPLE_KNOWLEDGE'] || DATA_PATH, 'img4.yaml')
        mappings_data = YAML.load_file(file_path)
        mappings_data['property_collections'].map do |p|
          mappings_data[p]
        end.reduce(&:merge).deep_symbolize_keys.with_indifferent_access
      end

      def self.friendly=(friendly)
        @friendly = friendly
      end

      def self.friendly
        @friendly ||= false
      end

      def self.key_name(key)
        if friendly
          string_result = mappings.dig(key, 'title') || mappings.dig(key, 'name') || mappings.dig(key, 'description')
          return Models::DescriptorResult.new key, string_result if string_result
        end

        key
      end
    end
  end
end
