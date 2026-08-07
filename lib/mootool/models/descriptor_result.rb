# frozen_string_literal: true

module MooTool
  module Models
    # Represents a mapping between a 4CC key and its human-readable description
    class DescriptorResult
      # @return [Symbol] The 4CC key.
      attr_reader :key
      # @return [String] The human-readable name or description.
      attr_reader :string_name

      # Initializes a new DescriptorResult
      #
      # @param key [Symbol] The 4CC key.
      # @param string_name [String] The human-readable name.
      def initialize(key, string_name)
        @key = key
        @string_name = string_name
      end

      # Compares this descriptor with another
      #
      # @param other [DescriptorResult, String, Symbol] The object to compare with.
      # @return [Boolean] True if the keys match.
      def ==(other)
        @key == case other
                when DescriptorResult
                  other.key
                when String
                  other.to_sym
                else
                  other
                end
      end
    end
  end
end
