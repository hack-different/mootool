# frozen_string_literal: true

module MooTool
  module Models::IMG4
    # A class representing a series of KeyValueProperties - mappable into a hash
    class PropertySequence
      include MooTool::Helpers::IMG4

      attr_reader :value, :key

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

      def to_h
        { Models::IMG4.key_name(@key) => @value.deep_transform_keys { |key| Models::IMG4.key_name(key) } }
      end

      def to_pair
        [Models::IMG4.key_name(@key), self]
      end

      def [](key)
        @value[key]
      end

      def inspect
        to_h.ai
      end
    end
  end
end
