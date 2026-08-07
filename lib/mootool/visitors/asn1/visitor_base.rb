# frozen_string_literal: true

require 'openssl'

module MooTool
  module Visitors
    module ASN1
      # VisitorBase visitor for traversing ASN1 structures from OpenSSL or RASN1.
      #
      # Provides recursive traversal of ASN1 trees with depth and parent tracking.
      # Subclasses implement {#visit_primitive}, {#visit_constructive}, and optionally
      # {#visit_private} to define behavior at each node.
      #
      # Accepts raw nodes from either OpenSSL::ASN1 or RASN1::Types and wraps them
      # in a unified adapter ({MooTool::Visitors::Adapters::AdapterBase}) before dispatching.
      #
      # Supports map/reduce style operations:
      # - Override {#visit_primitive} / {#visit_constructive} to transform (map) nodes.
      # - Override {#reduce} to aggregate results across children.
      #
      # @example Subclassing
      #   class CountVisitor < MooTool::Visitors::VisitorBase
      #     def visit_primitive(adapter)
      #       1
      #     end
      #
      #     def reduce(results)
      #       results.sum
      #     end
      #   end
      class VisitorBase
        # @return [Array<MooTool::Visitors::Adapters::AdapterBase>] The stack of parent adapters from root to current.
        attr_reader :parents

        # @return [Integer] The current depth in the ASN1 tree (0-based).
        attr_reader :depth

        # Initializes a new visitor with empty parent stack and zero depth.
        def initialize
          @parents = []
          @depth = 0
        end

        # Visits an ASN1 node, dispatching to the appropriate handler.
        #
        # Accepts raw nodes from OpenSSL::ASN1 or RASN1::Types and wraps them
        # in an adapter. Also accepts pre-wrapped adapters.
        #
        # Automatically recurses into constructed children,
        # tracking parents and depth throughout the traversal.
        #
        # @param node [OpenSSL::ASN1::ASN1Data, RASN1::Types::VisitorBase, MooTool::Visitors::Adapters::AdapterBase] The ASN1 node to visit.
        # @return [Object] The result of visiting this node.
        def visit(node)
          return visit_nil if node.nil?

          adapter = wrap_node(node)

          if adapter.private_tag?
            visit_private(adapter)
          elsif adapter.constructed?
            visit_and_recurse(adapter)
          else
            visit_primitive(adapter)
          end
        end

        # Returns the immediate parent adapter of the current node.
        #
        # @return [MooTool::Visitors::Adapters::AdapterBase, nil] The parent adapter, or nil at root.
        def parent
          @parents.last
        end

        # Returns true if the visitor is currently at the root level.
        #
        # @return [Boolean]
        def root?
          @depth.zero?
        end

        protected

        # Called when visiting a primitive (non-constructed) ASN1 node.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the primitive node.
        # @return [Object] The transformed value.
        def visit_primitive(adapter)
          adapter.node
        end

        # Called when visiting a constructive (Sequence, Set, etc.) ASN1 node.
        #
        # Receives the adapter and the already-visited children results.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the constructive node.
        # @param children [Array<Object>] The results of visiting each child.
        # @return [Object] The transformed value.
        def visit_constructive(_adapter, children)
          children
        end

        # Called when visiting a node with a PRIVATE tag class.
        #
        # By default, treats PRIVATE-tagged nodes with array values as constructive
        # and recurses into them, otherwise treats them as primitive.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the PRIVATE-tagged node.
        # @return [Object] The transformed value.
        def visit_private(adapter)
          if adapter.value.is_a?(Array)
            visit_and_recurse(adapter)
          else
            visit_primitive(adapter)
          end
        end

        # Called when visiting a nil node.
        #
        # @return [nil]
        def visit_nil
          nil
        end

        # Reduces an array of child results into a single value.
        #
        # Override this method to implement reduce/fold behavior across children.
        # By default returns the array unchanged.
        #
        # @param results [Array<Object>] The results from visiting each child.
        # @return [Object] The reduced result.
        def reduce(results)
          results
        end

        private

        # Wraps a raw ASN1 node in the appropriate adapter, or returns an
        # already-wrapped adapter unchanged.
        #
        # @param node [Object] The raw ASN1 node or adapter.
        # @return [MooTool::Visitors::Adapters::AdapterBase]
        def wrap_node(node)
          if node.is_a?(Adapters::AdapterBase)
            node
          else
            Adapters::AdapterBase.wrap(node)
          end
        end

        # Visits a constructive or PRIVATE node, recursing into its children.
        #
        # Manages the parent stack and depth counter around the recursion.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter whose children to visit.
        # @return [Object] The result of {#visit_constructive} with visited children.
        def visit_and_recurse(adapter)
          @parents.push(adapter)
          @depth += 1

          children = adapter.children.map { |child| visit(child) }
          reduced = reduce(children)

          @depth -= 1
          @parents.pop

          visit_constructive(adapter, reduced)
        end
      end
    end
  end
end
