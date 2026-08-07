# frozen_string_literal: true

module MooTool
  module Helpers
    # Represents a node in a tree structure for rendering or serialization
    #
    # This class allows building a tree of named nodes with children, which can
    # then be rendered as an ASCII tree or serialized to JSON/Hash.
    class TreeNode
      # @return [String] The name or label of the node.
      attr_accessor :name
      # @return [Array<TreeNode>] The child nodes of this node.
      attr_accessor :children

      # Initializes a new TreeNode
      #
      # @param name [Symbol, String, Object] The name of the node. Symbols are resolved via {Models::IMG4.key_name}.
      # @param children [Array<TreeNode>] Initial list of child nodes.
      def initialize(name, children = [])
        @name = case name
                when Symbol
                  Models::IMG4.key_name(name).ai
                when String
                  name
                else
                  name.ai
                end
        @children = children
      end

      # Creates a tree structure from a Hash
      #
      # @param hash [Hash, Object] The hash representing the tree, or a simple object to be treated as a leaf.
      # @return [TreeNode] The constructed tree.
      def self.from_h(hash)
        if hash.is_a?(Hash)
          raw_children = hash.key?(:children) ? hash[:children] : []
          children = raw_children.map { |ch| from_h(ch) }
          new hash[:name], children
        else
          new hash
        end
      end

      # Creates a tree structure from a JSON string
      #
      # @param json [String] The JSON representation of the tree.
      # @return [TreeNode] The constructed tree.
      def self.from_json(json)
        hash = JSON.parse json, symbolize_names: true
        from_h hash
      end

      # Converts the tree to a Hash representation
      #
      # @return [Hash] The tree as a hash.
      def to_h
        {
          name: @name,
          children: @children.map(&:to_h)
        }
      end

      # Converts the tree to a JSON string
      #
      # @param options [Hash] Options passed to JSON.generate.
      # @return [String] The JSON string.
      def to_json(**)
        JSON.generate(to_h, **)
      end

      # Renders the tree as an array of strings (ASCII tree)
      #
      # @return [Array<String>] The lines of the rendered tree.
      def render
        lines = @name.split("\n")
        @children.each_with_index do |child, index|
          child_lines = child.render
          if index < @children.size - 1
            child_lines.each_with_index do |line, idx|
              prefix = idx.zero? ? '├── ' : '|   '
              lines << "#{prefix}#{line}"
            end
          else
            child_lines.each_with_index do |line, idx|
              prefix = idx.zero? ? '└── ' : '    '
              lines << "#{prefix}#{line}"
            end
          end
        end
        lines
      end

      # Prints the rendered tree to a stream
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
