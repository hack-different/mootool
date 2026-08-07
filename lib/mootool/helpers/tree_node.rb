# frozen_string_literal: true

module MooTool
  module Helpers
    # Represents a node in a tree structure for rendering or serialization
    #
    # This class allows building a tree of named nodes with children, which can
    # then be rendered as an ASCII tree or serialized to JSON/Hash.
    #
    # TreeNode supports:
    # - A node type (e.g., :class, :module, :method) to classify the node
    # - An identifier string for the node
    # - A hash of arbitrary properties
    # - An ordered list of children (TreeNode or LeafNode)
    class TreeNode
      # @return [String] The name or label of the node.
      attr_accessor :name

      # @return [Array<TreeNode, LeafNode>] The child nodes of this node.
      attr_accessor :children

      # @return [Symbol, nil] The type of this node (e.g., :class, :module).
      attr_accessor :type

      # @return [String, nil] An identifier for this node.
      attr_accessor :id

      # @return [Hash] Arbitrary properties associated with this node.
      attr_accessor :properties

      # Initializes a new TreeNode
      #
      # @param name [Symbol, String, Object] The name of the node. Symbols are resolved via {Models::IMG4.key_name}.
      # @param children [Array<TreeNode, LeafNode>] Initial list of child nodes.
      # @param type [Symbol, nil] The type classification of this node.
      # @param id [String, nil] An identifier for this node.
      # @param properties [Hash] Arbitrary properties for this node.
      def initialize(name, children = [], type: nil, id: nil, properties: {})
        @name = case name
                when Symbol
                  Models::IMG4.key_name(name).ai
                when String
                  name
                else
                  name.ai
                end
        @children = children
        @type = type
        @id = id
        @properties = properties
      end

      # Accepts a visitor, calling {TreeVisitor#visit_tree} on it.
      #
      # @param visitor [TreeVisitor] The visitor to accept.
      # @return [Object] The result of the visitor's visit_tree method.
      def accept(visitor)
        visitor.visit_tree(self)
      end

      # Creates a tree structure from a Hash
      #
      # @param hash [Hash, Object] The hash representing the tree, or a simple object to be treated as a leaf.
      # @return [TreeNode, LeafNode] The constructed tree.
      def self.from_h(hash)
        if hash.is_a?(Hash)
          if hash.key?(:value) && !hash.key?(:children)
            LeafNode.new(hash[:value], key: hash[:key])
          else
            raw_children = hash.key?(:children) ? hash[:children] : []
            children = raw_children.map { |ch| from_h(ch) }
            new(hash[:name], children,
                type: hash[:type],
                id: hash[:id],
                properties: hash[:properties] || {})
          end
        else
          LeafNode.new(hash)
        end
      end

      # Creates a tree structure from a JSON string
      #
      # @param json [String] The JSON representation of the tree.
      # @return [TreeNode, LeafNode] The constructed tree.
      def self.from_json(json)
        hash = JSON.parse json, symbolize_names: true
        from_h hash
      end

      # Converts the tree to a Hash representation
      #
      # @return [Hash] The tree as a hash.
      def to_h
        result = { name: @name }
        result[:type] = @type if @type
        result[:id] = @id if @id
        result[:properties] = @properties unless @properties.empty?
        result[:children] = @children.map(&:to_h)
        result
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
      # Supports children that render over multiple lines by properly
      # continuing the tree connector characters.
      #
      # @return [Array<String>] The lines of the rendered tree.
      def render
        lines = render_header
        @children.each_with_index do |child, index|
          child_lines = child.render
          last_child = index == @children.size - 1
          child_lines.each_with_index do |line, idx|
            prefix = if last_child
                       idx.zero? ? '└───◦ ' : '    '
                     else
                       idx.zero? ? '├───◦ ' : '│   '
                     end
            lines << "#{prefix}#{line}"
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

      private

      # Renders the header lines for this node, including type, id, and properties.
      #
      # @return [Array<String>] The header lines.
      def render_header
        parts = []
        parts << @type if @type
        parts << @id.ai if @id
        header = parts.join(' @ ')
        name_fixup = @name.split("\n").map.with_index do |l, idx|
          idx.zero? ? l : "  #{l}"
        end.join("\n")
        header = if parts.any?
                   "#{header}\n  #{name_fixup}"
                 else
                   name_fixup
                 end

        lines = header.split("\n")

        @properties.each do |key, value|
          value.ai.split("\n").each_with_index do |val_line, idx|
            lines << if idx.zero?
                       "│   #{key.ai} => #{val_line}"
                     else
                       "│   #{val_line}"
                     end
          end
        end

        lines
      end
    end
  end
end
