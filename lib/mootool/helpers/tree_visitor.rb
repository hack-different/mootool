# frozen_string_literal: true

module MooTool
  module Helpers
    # Base class for tree visitors implementing the visitor pattern for TreeNode/LeafNode.
    #
    # Subclass and override {#visit_tree} and/or {#visit_leaf} to define
    # custom traversal behavior. The default implementation performs a
    # depth-first traversal collecting results from all children.
    #
    # @example Collecting all leaf values
    #   class LeafCollector < MooTool::Helpers::TreeVisitor
    #     def visit_leaf(leaf)
    #       leaf.value
    #     end
    #
    #     def visit_tree(node)
    #       visit_children(node).flatten
    #     end
    #   end
    class TreeVisitor
      # @return [Integer] The current depth in the tree (0-based).
      attr_reader :depth

      # @return [Array<TreeNode>] The stack of parent nodes from root to current.
      attr_reader :parents

      # Initializes a new TreeVisitor with empty parent stack and zero depth.
      def initialize
        @depth = 0
        @parents = []
      end

      # Returns the immediate parent node.
      #
      # @return [TreeNode, nil] The parent node, or nil at root.
      def parent
        @parents.last
      end

      # Returns true if the visitor is at the root level.
      #
      # @return [Boolean]
      def root?
        @depth.zero?
      end

      # Visits a TreeNode. Override in subclasses to customize behavior.
      #
      # The default implementation returns a hash with the node's name
      # and the results of visiting all children.
      #
      # @param node [TreeNode] The tree node to visit.
      # @return [Object] The result of visiting this node.
      def visit_tree(node)
        { name: node.name, children: visit_children(node) }
      end

      # Visits a LeafNode. Override in subclasses to customize behavior.
      #
      # The default implementation returns the leaf's value (or key/value hash).
      #
      # @param leaf [LeafNode] The leaf node to visit.
      # @return [Object] The result of visiting this leaf.
      def visit_leaf(leaf)
        leaf.key_value? ? { leaf.key => leaf.value } : leaf.value
      end

      protected

      # Visits all children of a TreeNode, managing depth and parent tracking.
      #
      # @param node [TreeNode] The parent node whose children to visit.
      # @return [Array<Object>] The results of visiting each child.
      def visit_children(node)
        @parents.push(node)
        @depth += 1

        results = node.children.map { |child| child.accept(self) }

        @depth -= 1
        @parents.pop

        results
      end
    end
  end
end
