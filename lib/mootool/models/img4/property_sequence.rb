# frozen_string_literal: true

module MooTool
  module Models::IMG4
    # Represents a sequence of Key/Value properties, which can be mapped into a hash.
    class PropertySequence
      include MooTool::Helpers::IMG4

      # @return [Hash] The mapped key-value properties.
      attr_reader :value

      # @return [Symbol, String] The identifying key for this sequence.
      attr_reader :key

      # Initializes a new PropertySequence from ASN.1 data.
      #
      # @param input [OpenSSL::ASN1::ASN1Data] The raw ASN.1 structure to parse.
      def initialize(input)
        construction = construct(input.value.first)
        @key = Models::IMG4.key_name(construction[0])
        value = construction[1]

        @value = value.to_h do |element|
          element.respond_to?(:to_pair) ? element.to_pair : element.first
        end
      rescue StandardError => e
        puts "Unable to handle #{input.ai}\n#{e.full_message}"
      end

      # Converts the property sequence into a tree structure for visualization.
      #
      # @return [Helpers::TreeNode] The root node of the generated tree.
      def to_tree
        node = Helpers::TreeNode.new(Models::IMG4.key_name(@key).ai)

        @value.each do |key, value|
          node.children << if value.respond_to? :to_tree
                             Helpers::TreeNode.new(Models::IMG4.key_name(key).ai, [value.to_tree])
                           else
                             Helpers::TreeNode.new(Models::IMG4.key_name(key).ai, [Helpers::TreeNode.new(value.ai)])
                           end
        end

        node
      end

      # Converts the property sequence to a hash representation.
      #
      # @return [Hash] A hash mapping the sequence key to its internal values.
      def to_h
        { Models::IMG4.key_name(@key) => @value.deep_transform_keys { |key| Models::IMG4.key_name(key) } }
      end

      # Returns the property sequence as a key-value pair.
      #
      # @return [Array(Symbol, PropertySequence)] An array containing the key and this instance.
      def to_pair
        [Models::IMG4.key_name(@key), self]
      end

      # Retrieves a value from the sequence by its key.
      #
      # @param key [Symbol, String] The key to look up.
      # @return [Object, nil] The value associated with the key.
      def [](key)
        @value[key]
      end

      # Provides a human-readable inspection of the property sequence.
      #
      # @return [String] The awesome_print representation.
      def inspect
        to_h.ai
      end
    end
  end
end
