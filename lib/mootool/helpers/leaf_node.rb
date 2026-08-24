# frozen_string_literal: true

module MooTool
  module Helpers
    # Represents a leaf node in a tree structure that holds a simple string value
    # or an optional key/value pair.
    #
    # LeafNode is a terminal node with no children. It can represent either:
    # - A simple string value (e.g., LeafNode.new("hello"))
    # - A key/value pair (e.g., LeafNode.new("hello", key: "greeting"))
    class LeafNode
      # @return [String] The value of this leaf.
      attr_accessor :value

      # @return [String, nil] The optional key for this leaf.
      attr_accessor :key

      # Initializes a new LeafNode
      #
      # @param value [String, Object] The value of the leaf. Non-strings are converted via #to_s.
      # @param key [String, Symbol, nil] An optional key to form a key/value pair.
      def initialize(value, key: nil, props: nil)
        @value = value.is_a?(String) ? value : value.to_s
        @key = key&.to_s
        @props = props
      end

      # Returns true if this leaf has a key (key/value form).
      #
      # @return [Boolean]
      def key_value?
        !@key.nil?
      end

      # Accepts a visitor, calling {TreeVisitor#visit_leaf} on it.
      #
      # @param visitor [TreeVisitor] The visitor to accept.
      # @return [Object] The result of the visitor's visit_leaf method.
      def accept(visitor)
        visitor.visit_leaf(self)
      end

      # Converts the leaf to a Hash representation.
      #
      # @return [Hash] The leaf as a hash.
      def to_h
        result = { value: @value }
        result[:key] = @key if @key
        result
      end

      # Renders the leaf as an array of strings for ASCII tree output.
      #
      # @return [Array<String>] The lines of the rendered leaf.
      def render
        display = key_value? ? "#{@key}: #{@value}" : @value
        display.split("\n")
      end

      # Prints the rendered leaf to a stream.
      #
      # @param stream [IO] The stream to print to (default: $stdout).
      # @param prefix [String] A prefix to add to each line.
      # @return [void]
      def print(stream: $stdout, prefix: '')
        stream.puts(render.map { |line| "#{prefix}#{line}\n" })
      end
    end
  end
end
