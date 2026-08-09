# frozen_string_literal: true

require 'openssl'

module MooTool
  module Visitors
    module ASN1
      # Visitor that validates ASN1 structures against RASN2 type expectations.
      #
      # Works with both OpenSSL::ASN1 and RASN2::Types nodes via adapters.
      #
      # Walks an ASN1 tree and checks each node against a parallel RASN2 model structure,
      # collecting validation errors with path information.
      #
      # Supports PRIVATE tag validation, optional/required field checks, and
      # type matching against RASN2 type systems.
      #
      # @example Validating a structure
      #   schema = RASN2::Types::Sequence.new
      #   schema.value = [RASN2::Types::Integer.new, RASN2::Types::OctetString.new]
      #
      #   visitor = MooTool::Visitors::ValidationVisitor.new(schema)
      #   result = visitor.visit(asn1_structure)
      #   visitor.valid?    #=> true or false
      #   visitor.errors    #=> [] or ["path: error message", ...]
      class ValidationVisitor < VisitorBase
        # Tag number mapping from RASN2 type names to ASN1 universal tag numbers.
        RASN2_TYPE_TO_TAG = {
          boolean: 1,
          integer: 2,
          bit_string: 3,
          octet_string: 4,
          null: 5,
          object_id: 6,
          enumerated: 10,
          utf8_string: 12,
          sequence: 16,
          set: 17,
          numeric_string: 18,
          printable_string: 19,
          t61_string: 20,
          ia5_string: 22,
          utc_time: 23,
          generalized_time: 24,
          universal_string: 28,
          bmp_string: 30
        }.freeze

        # @return [Array<String>] Collected validation error messages.
        attr_reader :errors

        # Initializes a new ValidationVisitor with a RASN2 schema.
        #
        # @param schema [RASN2::Types::Base, nil] The RASN2 type to validate against.
        #   If nil, only structural validation is performed.
        def initialize(schema = nil)
          super()
          @schema = schema
          @errors = []
          @schema_stack = schema ? [schema] : []
          @path = []
        end

        # Returns whether the visited structure passed validation.
        #
        # @return [Boolean] true if no errors were collected.
        def valid?
          @errors.empty?
        end

        # Visits an ASN1 node, validating it against the current schema position.
        #
        # @param node [OpenSSL::ASN1::ASN1Data, RASN2::Types::Base, MooTool::Visitors::Adapters::AdapterBase] The ASN1 node to validate.
        # @return [Boolean] true if this node is valid.
        def visit(node)
          return visit_nil if node.nil?

          adapter = wrap_node(node)
          current_schema = @schema_stack.last

          validate_against_schema(adapter, current_schema) if current_schema

          if adapter.private_tag?
            visit_private(adapter)
          elsif adapter.constructed?
            visit_and_recurse(adapter)
          else
            visit_primitive(adapter)
          end
        end

        # Returns true after validation if the structure is valid.
        #
        # @param node [OpenSSL::ASN1::ASN1Data, RASN2::Types::Base, MooTool::Visitors::Adapters::AdapterBase] The root ASN1 node.
        # @return [Boolean] true if the structure is valid.
        def validate(node)
          visit(node)
          valid?
        end

        protected

        # Validates a primitive node and returns true.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the primitive node.
        # @return [Boolean] Always true (errors are collected separately).
        def visit_primitive(_adapter)
          true
        end

        # Validates a constructive node and its children.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the constructive node.
        # @param children [Array<Boolean>] The validation results of each child.
        # @return [Boolean] true if all children are valid.
        def visit_constructive(_adapter, children)
          children.all?
        end

        # Validates a PRIVATE-tagged node.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the PRIVATE-tagged node.
        # @return [Boolean] true if the node is valid.
        def visit_private(adapter)
          label = adapter.tag_label
          @path.push(label.to_s)

          result = if adapter.value.is_a?(Array)
                     @parents.push(adapter)
                     @depth += 1

                     children = adapter.children.map { |child| visit(child) }

                     @depth -= 1
                     @parents.pop

                     children.all?
                   else
                     true
                   end

          @path.pop
          result
        end

        # Reduces validation results by conjunction.
        #
        # @param results [Array<Boolean>] The child validation results.
        # @return [Array<Boolean>] The results unchanged (conjunction done in visit_constructive).
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

        # Validates a node against its corresponding RASN2 schema type.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the ASN1 node.
        # @param schema [RASN2::Types::Base] The expected RASN2 type.
        def validate_against_schema(adapter, schema)
          validate_tag_class(adapter, schema)
          validate_tag_type(adapter, schema)
          push_child_schemas(adapter, schema)
        end

        # Checks that the tag class matches the schema expectation.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the ASN1 node.
        # @param schema [RASN2::Types::Base] The expected RASN2 type.
        def validate_tag_class(adapter, schema)
          expected_class = schema.asn1_class.to_s.upcase.to_sym
          actual_class = adapter.tag_class

          return if expected_class == actual_class
          return if expected_class == :UNIVERSAL && actual_class == :UNIVERSAL

          add_error("expected tag class #{expected_class}, got #{actual_class}")
        end

        # Checks that the tag type matches the schema expectation.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the ASN1 node.
        # @param schema [RASN2::Types::Base] The expected RASN2 type.
        def validate_tag_type(adapter, schema)
          return if adapter.private_tag?

          expected_tag = rasn1_type_to_tag(schema)
          return if expected_tag.nil?
          return if adapter.tag == expected_tag

          add_error("expected tag #{expected_tag} (#{schema.type}), got #{adapter.tag}")
        end

        # Pushes child schemas onto the stack for constructed types.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the ASN1 node.
        # @param schema [RASN2::Types::Base] The current schema type.
        def push_child_schemas(adapter, schema)
          return unless schema.respond_to?(:value) && schema.value.is_a?(Array)
          return unless adapter.value.is_a?(Array)

          schema.value.each_with_index do |child_schema, index|
            next unless child_schema.is_a?(rasn1_base_class)

            if index < adapter.children.size
              @schema_stack.push(child_schema)
            elsif !child_schema.optional?
              add_error("missing required element at index #{index} (#{child_schema.type})")
            end
          end
        end

        # Resolves the RASN2 base type class, loading rasn1 if available.
        #
        # @return [Class] The RASN2::Types::Base class, or a fallback.
        def rasn1_base_class
          @rasn1_base_class ||= begin
            require 'rasn2'
            RASN2::Types::Base
          rescue LoadError
            # Fallback if rasn1 is not available
            Class.new
          end
        end

        # Converts a RASN2 type to its corresponding ASN1 tag number.
        #
        # @param schema [RASN2::Types::Base] The RASN2 type.
        # @return [Integer, nil] The ASN1 tag number, or nil if unknown.
        def rasn1_type_to_tag(schema)
          type_name = schema.type.to_s.downcase
          type_key = type_name.gsub(/\s+/, '_').to_sym
          RASN2_TYPE_TO_TAG[type_key]
        end

        # Records a validation error with the current path context.
        #
        # @param message [String] The error description.
        def add_error(message)
          path_str = @path.empty? ? 'root' : @path.join('/')
          @errors << "#{path_str}: #{message}"
        end
      end
    end
  end
end
